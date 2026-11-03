import {
  Injectable,
  BadRequestException,
  Logger,
  BadGatewayException,
  NotFoundException,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { randomUUID } from 'crypto';
import {
  LocationAutocompleteQueryDto,
  LocationAutocompleteResponseDto,
  PlaceSuggestionDto,
} from './dto/location-autocomplete.dto';
import { PlaceDetailResponseDto } from './dto/place-detail.dto';
import {
  ReverseGeocodeQueryDto,
  ReverseGeocodeResponseDto,
} from './dto/reverse-geocode.dto';
import { CitiesQueryDto, CitiesResponseDto, CityDto } from './dto/cities.dto';
import { CITY_BY_ID, CITY_CATALOG } from './cities.data';
import { PlacesRateLimiter } from './places-rate-limiter';

type CacheEntry<T> = {
  expiresAt: number;
  value: T;
};

/** Search context a request is resolved against: explicit coords or a city. */
interface SearchContext {
  lat: number;
  lng: number;
  /** Set when the context came from `cityId`, which also restricts results. */
  city?: CityDto;
}

/** Radius the search is biased to around the passenger. */
const LOCAL_SEARCH_RADIUS_KM = 50;

/** A Google plus code ("7VJX+2VM", "7VJX+4P"), which names no place. */
const PLUS_CODE =
  /^[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{0,3}\s*/i;

/** Places API (New) autocomplete prediction, the fields we read. */
interface GooglePlacePrediction {
  placeId: string;
  text?: { text?: string };
  structuredFormat?: {
    mainText?: { text?: string };
    secondaryText?: { text?: string };
  };
  distanceMeters?: number;
}

/** Places API (New) place, as asked for by the field mask. */
interface GooglePlace {
  id?: string;
  displayName?: { text?: string };
  formattedAddress?: string;
  location?: { latitude?: number; longitude?: number };
}

interface GoogleAddressComponent {
  long_name?: string;
  short_name?: string;
  types?: string[];
}

interface GoogleGeocodeResult {
  formatted_address?: string;
  types?: string[];
  address_components?: GoogleAddressComponent[];
}

@Injectable()
export class LocationsService {
  private readonly logger = new Logger(LocationsService.name);
  private readonly googleMapsApiKey: string;
  private readonly googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';
  private readonly osrmBaseUrl = 'https://router.project-osrm.org';
  /**
   * Place search and lookup: Google Places API (New), on the same key as the
   * maps. It replaced the free public OpenStreetMap geocoder, which refused
   * our server's requests at busy times and left search saying «تعذر البحث».
   */
  private readonly placesBaseUrl = 'https://places.googleapis.com/v1';
  /** The list wording of recent suggestions, by placeId, for their lookup. */
  private readonly labels = new Map<string, string>();
  /**
   * ISO country codes that place suggestions are restricted to. Empty means
   * suggestions are global (still biased toward the user's coordinates when
   * provided), which is the default now that the app operates across multiple
   * countries.
   */
  private readonly autocompleteCountries: string[];
  private readonly autocompleteCache = new Map<
    string,
    CacheEntry<PlaceSuggestionDto[]>
  >();
  private readonly reverseCache = new Map<
    string,
    CacheEntry<ReverseGeocodeResponseDto>
  >();
  /**
   * Country of a search context, keyed by coordinates rounded to ~1 km, so an
   * older app that sends no `country` still gets foreign places dropped
   * without a reverse lookup on every keystroke.
   */
  private readonly contextCountryCache = new Map<string, string>();
  private readonly cacheTtlMs = 60_000;
  /** Cap on cached entries so a long-lived process cannot grow unbounded. */
  private readonly cacheMaxEntries = 500;
  /** Provider timeout. Search is interactive: a slow answer is a failed one. */
  private readonly providerTimeoutMs = 3_000;
  /** Consecutive provider failures before the breaker opens. */
  private readonly breakerThreshold = 5;
  private readonly breakerCooldownMs = 30_000;
  private providerFailures = 0;
  private breakerOpenUntil = 0;
  /** Suggestions returned to the app. */
  private readonly suggestionLimit = 6;

  constructor(
    private configService: ConfigService,
    private readonly rateLimiter: PlacesRateLimiter,
  ) {
    this.googleMapsApiKey = this.configService.get<string>(
      'GOOGLE_MAPS_API_KEY',
      '',
    );
    // Comma-separated ISO country codes (e.g. "jo,eg,sa") to scope place
    // suggestions to. Unset → global suggestions.
    this.autocompleteCountries = (
      this.configService.get<string>('LOCATION_AUTOCOMPLETE_COUNTRIES') || ''
    )
      .split(',')
      .map((code) => code.trim().toLowerCase())
      .filter((code) => code.length > 0)
      .slice(0, 5);
  }

  async autocomplete(
    query: LocationAutocompleteQueryDto,
    userId: string,
  ): Promise<LocationAutocompleteResponseDto> {
    const q = query.q?.trim() ?? '';
    const sessionToken = query.sessionToken?.trim() || randomUUID();

    if (q.length < 2) {
      return { sessionToken, suggestions: [] };
    }

    await this.assertWithinRateLimit(userId);

    const lang = query.lang === 'en' ? 'en' : 'ar';
    const context = this.resolveSearchContext(query);
    const country =
      context?.city?.countryCode.toLowerCase() ??
      query.country?.toLowerCase() ??
      (context ? await this.countryOfContext(context) : undefined);
    const cacheKey = [
      q.toLowerCase(),
      lang,
      this.autocompleteCountries.join(','),
      country ?? '-',
      context?.city?.id ?? '-',
      this.contextKey(context),
    ].join('|');
    const cached = this.getCached(this.autocompleteCache, cacheKey);
    if (cached) {
      return { sessionToken, suggestions: cached };
    }

    this.assertProviderAvailable();

    let predictions: GooglePlacePrediction[];
    try {
      predictions = await this.googleAutocomplete(
        q,
        lang,
        sessionToken,
        context,
        this.regionCodes(country),
      );
      this.recordProviderSuccess();
    } catch (error) {
      this.recordProviderFailure();
      this.logger.warn(
        `Google Places autocomplete failed: ${this.googleErrorMessage(error)}`,
      );
      throw new BadGatewayException('Places provider unavailable');
    }

    const ranked = this.rankSuggestions(
      predictions
        .map((prediction) => this.toSuggestion(prediction))
        .filter((suggestion) => suggestion.placeId)
        .map((suggestion) => ({ suggestion, demoted: false })),
      context,
    );
    const suggestions = this.promoteCityMatches(
      ranked,
      q,
      context,
      country,
    ).slice(0, this.suggestionLimit);

    // The place lookup that follows a tap returns Google's own address; the
    // passenger should see the same words they picked from the list.
    for (const suggestion of suggestions) {
      this.rememberLabel(suggestion.placeId, suggestion.description);
    }
    this.setCached(this.autocompleteCache, cacheKey, suggestions);
    return { sessionToken, suggestions };
  }

  /**
   * Places API (New) autocomplete. Biased to 50 km around the passenger and,
   * when the country is known, restricted to it: from Al-Ula, «مستشفى» must
   * not list hospitals in another country.
   */
  private async googleAutocomplete(
    q: string,
    lang: 'ar' | 'en',
    sessionToken: string,
    context?: SearchContext,
    regionCodes?: string[],
  ): Promise<GooglePlacePrediction[]> {
    const center = context
      ? { latitude: context.lat, longitude: context.lng }
      : undefined;
    const response = await axios.post<{
      suggestions?: Array<{ placePrediction?: GooglePlacePrediction }>;
    }>(
      `${this.placesBaseUrl}/places:autocomplete`,
      {
        input: q,
        languageCode: lang,
        sessionToken,
        ...(regionCodes?.length ? { includedRegionCodes: regionCodes } : {}),
        ...(center
          ? {
              locationBias: {
                circle: { center, radius: LOCAL_SEARCH_RADIUS_KM * 1000 },
              },
              // Gives each suggestion its distance from the passenger.
              origin: center,
            }
          : {}),
      },
      {
        headers: { 'X-Goog-Api-Key': this.googleMapsApiKey },
        timeout: this.providerTimeoutMs,
      },
    );
    return (response.data?.suggestions ?? [])
      .map((entry) => entry.placePrediction)
      .filter((p): p is GooglePlacePrediction => !!p?.placeId);
  }

  /** Google's place prediction as the two lines the app renders. */
  private toSuggestion(prediction: GooglePlacePrediction): PlaceSuggestionDto {
    const primaryText = (
      prediction.structuredFormat?.mainText?.text ??
      prediction.text?.text ??
      ''
    ).trim();
    const secondaryText = (
      prediction.structuredFormat?.secondaryText?.text ?? ''
    ).trim();
    return {
      placeId: primaryText ? prediction.placeId : '',
      primaryText,
      secondaryText,
      description: (
        prediction.text?.text ??
        [primaryText, secondaryText].filter(Boolean).join('، ')
      ).trim(),
      distanceMeters:
        typeof prediction.distanceMeters === 'number'
          ? prediction.distanceMeters
          : null,
    };
  }

  /** Countries a search may return: the passenger's, within the configured set. */
  private regionCodes(country?: string): string[] | undefined {
    if (country) {
      if (
        this.autocompleteCountries.length > 0 &&
        !this.autocompleteCountries.includes(country)
      ) {
        return this.autocompleteCountries;
      }
      return [country];
    }
    return this.autocompleteCountries.length > 0
      ? this.autocompleteCountries
      : undefined;
  }

  /** ISO country of a search context (lower case), or undefined if unknown. */
  private async countryOfContext(
    context: SearchContext,
  ): Promise<string | undefined> {
    const key = `${context.lat.toFixed(2)},${context.lng.toFixed(2)}`;
    const cached = this.contextCountryCache.get(key);
    if (cached) return cached;
    const geo = await this.reverseGeocodeGoogle(context.lat, context.lng).catch(
      () => null,
    );
    const code = geo?.countryCode ? geo.countryCode.toLowerCase() : undefined;
    // Only answers are remembered: a provider hiccup must not stick.
    if (code) {
      if (this.contextCountryCache.size >= this.cacheMaxEntries) {
        this.contextCountryCache.clear();
      }
      this.contextCountryCache.set(key, code);
    }
    return code;
  }

  /**
   * Make a query that names a city resolve to that city, first.
   *
   * Proximity ranking otherwise buries a distant city under nearby noise:
   * measured from Amman, "العقبه" put a shop 4 km away above Aqaba 300 km
   * south, and "اربد" put a hamlet above Irbid. If the provider already found
   * the city it is lifted to the top; otherwise the catalog entry is added,
   * which also covers cities the provider spells differently.
   *
   * Skipped once a city has been chosen, since the user is then searching for
   * an address inside it, not for another city.
   */
  private promoteCityMatches(
    suggestions: PlaceSuggestionDto[],
    q: string,
    context?: SearchContext,
    country?: string,
  ): PlaceSuggestionDto[] {
    if (context?.city) return suggestions;

    const needle = this.normalizeForSearch(q);
    // Two letters match far too many city names to be a useful signal.
    if (needle.length < 3) return suggestions;

    const city = CITY_CATALOG.find(
      (candidate) =>
        (!country || candidate.countryCode.toLowerCase() === country) &&
        (this.normalizeForSearch(candidate.nameAr).startsWith(needle) ||
          this.normalizeForSearch(candidate.nameEn).startsWith(needle)),
    );
    if (!city) return suggestions;

    const cityName = this.normalizeForSearch(city.nameAr);
    const alreadyFound = suggestions.findIndex(
      (suggestion) =>
        this.normalizeForSearch(suggestion.primaryText) === cityName &&
        this.isNearCity(suggestion, city),
    );

    if (alreadyFound >= 0) {
      const match = suggestions[alreadyFound];
      return [
        match,
        ...suggestions.filter((_, index) => index !== alreadyFound),
      ];
    }

    return [this.cityAsSuggestion(city, context), ...suggestions];
  }

  /**
   * True when a same-named suggestion is that city. Google's are filtered to
   * the passenger's country, so the name is enough; the catalog's own entries
   * carry coordinates and must sit where the city is.
   */
  private isNearCity(suggestion: PlaceSuggestionDto, city: CityDto): boolean {
    const point = this.decodePlaceId(suggestion.placeId);
    if (!point) return true;
    return (
      this.haversineMeters(point.lat, point.lng, city.lat, city.lng) <= 25_000
    );
  }

  /** Present a catalog city as a suggestion the client can select normally. */
  private cityAsSuggestion(
    city: CityDto,
    context?: SearchContext,
  ): PlaceSuggestionDto {
    const description = `${city.nameAr}، ${city.countryCode}`;
    return {
      placeId: this.encodePlaceId({
        lat: city.lat,
        lng: city.lng,
        label: city.nameAr,
      }),
      primaryText: city.nameAr,
      secondaryText: city.countryCode,
      description,
      distanceMeters: context
        ? Math.round(
            this.haversineMeters(context.lat, context.lng, city.lat, city.lng),
          )
        : null,
    };
  }

  /** Resolve a point-on-map to a display address (Google Geocoding). */
  async reverse(
    query: ReverseGeocodeQueryDto,
    userId: string,
  ): Promise<ReverseGeocodeResponseDto> {
    const lat = Number(query.lat);
    const lng = Number(query.lng);
    if (!this.isValidLatitude(lat) || !this.isValidLongitude(lng)) {
      throw new BadRequestException('Invalid coordinates');
    }

    await this.assertWithinRateLimit(userId);

    const lang = query.lang === 'en' ? 'en' : 'ar';
    // Round to ~11 m so tiny camera jitter reuses the cached answer.
    const cacheKey = `${lat.toFixed(4)},${lng.toFixed(4)}|${lang}`;
    const cached = this.getCached(this.reverseCache, cacheKey);
    if (cached) return cached;

    this.assertProviderAvailable();

    let results: GoogleGeocodeResult[];
    try {
      results = await this.googleGeocodeResults(lat, lng, lang);
      this.recordProviderSuccess();
    } catch (error) {
      this.recordProviderFailure();
      this.logger.warn(
        `Google reverse geocode failed: ${this.googleErrorMessage(error)}`,
      );
      throw new BadGatewayException('Places provider unavailable');
    }

    // A plus code ("8G3Q+2X عمان") names no place a passenger would know.
    const best =
      results.find((r) => !r.types?.includes('plus_code')) ?? results[0];
    const parts = (best?.formatted_address ?? '')
      .split(/[،,]\s*/)
      // Rural points come back as "7VJX+2VM، جرش، الأردن": keep the town.
      .map((part) => part.replace(PLUS_CODE, '').trim())
      .filter(Boolean);
    const result: ReverseGeocodeResponseDto = {
      primaryText: parts[0] ?? '',
      secondaryText: parts.slice(1).join('، '),
      label: parts.join('، '),
      city: this.cityName(best?.address_components),
      lat,
      lng,
    };
    this.setCached(this.reverseCache, cacheKey, result);
    return result;
  }

  /**
   * The town a point is in, for a profile's city field: the locality, else
   * the district, else the region — without the administrative prefix, so
   * "محافظة العلا" reads "العلا".
   */
  private cityName(components?: GoogleAddressComponent[]): string {
    const of = (type: string) =>
      components?.find((c) => c.types?.includes(type))?.long_name;
    const raw = (
      of('locality') ??
      of('administrative_area_level_2') ??
      of('administrative_area_level_1') ??
      ''
    ).trim();
    return raw
      .replace(/^(محافظة|منطقة|مدينة)\s+/, '')
      .replace(/\s+(Governorate|Province|Region)$/i, '')
      .trim();
  }

  /**
   * City catalog for the city-first route pickers. Served from a static list,
   * not the places provider: the set is small and must render instantly.
   */
  cities(query: CitiesQueryDto): CitiesResponseDto {
    const country = query.country?.trim().toUpperCase();
    const needle = this.normalizeForSearch(query.q ?? '');

    const cities = CITY_CATALOG.filter((city) => {
      if (country && city.countryCode !== country) return false;
      if (
        this.autocompleteCountries.length > 0 &&
        !this.autocompleteCountries.includes(city.countryCode.toLowerCase())
      ) {
        return false;
      }
      if (!needle) return true;
      return (
        this.normalizeForSearch(city.nameAr).includes(needle) ||
        this.normalizeForSearch(city.nameEn).includes(needle)
      );
    });

    return { cities };
  }

  /**
   * Pick the coordinates a search is measured and biased against: an explicit
   * `lat`/`lng` pair wins, otherwise the chosen city's centre.
   */
  private resolveSearchContext(
    query: LocationAutocompleteQueryDto,
  ): SearchContext | undefined {
    const city = query.cityId ? CITY_BY_ID.get(query.cityId) : undefined;
    const lat = this.coordinate(query.lat);
    const lng = this.coordinate(query.lng);

    // Both coordinates are required; a lone `lat` is a client bug, not a bias.
    if (
      lat !== undefined &&
      lng !== undefined &&
      this.isValidLatitude(lat) &&
      this.isValidLongitude(lng)
    ) {
      return { lat, lng, city };
    }

    if (city) return { lat: city.lat, lng: city.lng, city };
    return undefined;
  }

  /**
   * Order suggestions the way inDrive does: strictly nearest first. Google
   * returns each suggestion's distance from the passenger; its own relevance
   * only breaks ties, and decides the whole order when no context was sent.
   */
  private rankSuggestions(
    entries: Array<{ suggestion: PlaceSuggestionDto; demoted: boolean }>,
    context?: SearchContext,
  ): PlaceSuggestionDto[] {
    const distanceOf = (suggestion: PlaceSuggestionDto): number => {
      if (!context) return 0;
      return suggestion.distanceMeters ?? Number.POSITIVE_INFINITY;
    };

    // `map`+`sort` on the index keeps the sort stable across Node versions,
    // preserving the provider's own relevance order on equal distance.
    return entries
      .map((entry, index) => ({
        entry,
        index,
        distance: distanceOf(entry.suggestion),
      }))
      .sort(
        (a, b) =>
          a.distance - b.distance ||
          Number(a.entry.demoted) - Number(b.entry.demoted) ||
          a.index - b.index,
      )
      .map(({ entry }) => entry.suggestion);
  }

  /**
   * Coordinates of a picked suggestion. Catalog cities carry theirs in the
   * id; a Google place is looked up once, in the same billing session as the
   * search that listed it.
   */
  async placeDetail(
    placeId: string,
    sessionToken?: string,
  ): Promise<PlaceDetailResponseDto> {
    const id = placeId?.trim();
    if (!id) throw new NotFoundException('Place not found');

    const decoded = this.decodePlaceId(id);
    if (decoded) {
      return {
        placeId: id,
        label: decoded.label,
        lat: decoded.lat,
        lng: decoded.lng,
      };
    }
    if (id.startsWith('osm:') || !/^[A-Za-z0-9_-]+$/.test(id)) {
      throw new NotFoundException('Place not found');
    }

    let place: GooglePlace;
    try {
      const response = await axios.get<GooglePlace>(
        `${this.placesBaseUrl}/places/${id}`,
        {
          params: sessionToken ? { sessionToken } : undefined,
          headers: {
            'X-Goog-Api-Key': this.googleMapsApiKey,
            'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
          },
          timeout: this.providerTimeoutMs,
        },
      );
      place = response?.data;
    } catch (error) {
      if (axios.isAxiosError(error) && error.response?.status === 404) {
        throw new NotFoundException('Place not found');
      }
      this.logger.warn(
        `Google place details failed: ${this.googleErrorMessage(error)}`,
      );
      throw new BadGatewayException('Places provider unavailable');
    }

    const lat = Number(place?.location?.latitude);
    const lng = Number(place?.location?.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      throw new NotFoundException('Place not found');
    }
    const name = place.displayName?.text?.trim() ?? '';
    const address = place.formattedAddress?.trim() ?? '';
    return {
      placeId: id,
      label:
        this.labels.get(id) ??
        (name && !address.startsWith(name)
          ? [name, address].filter(Boolean).join('، ')
          : address || name),
      lat,
      lng,
    };
  }

  /** Remember the list wording of a suggestion for its place lookup. */
  private rememberLabel(placeId: string, label: string) {
    if (!label || this.decodePlaceId(placeId)) return;
    if (this.labels.size >= this.cacheMaxEntries * 4) this.labels.clear();
    this.labels.set(placeId, label);
  }

  /** Google's reason for a refusal (key, billing, API not enabled), if any. */
  private googleErrorMessage(error: unknown): string {
    if (axios.isAxiosError(error)) {
      const data = error.response?.data as
        | { error?: { status?: string; message?: string } }
        | undefined;
      if (data?.error) {
        return `${data.error.status ?? error.response?.status}: ${data.error.message ?? ''}`;
      }
    }
    return (error as Error)?.message ?? 'unknown error';
  }

  /** Great-circle distance in metres, for the suggestion distance label. */
  private haversineMeters(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const earthRadiusMeters = 6_371_000;
    const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
    const dLat = toRadians(lat2 - lat1);
    const dLng = toRadians(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRadians(lat1)) *
        Math.cos(toRadians(lat2)) *
        Math.sin(dLng / 2) ** 2;
    return 2 * earthRadiusMeters * Math.asin(Math.min(1, Math.sqrt(a)));
  }

  /** Case/diacritic-insensitive comparison key for city name filtering. */
  private normalizeForSearch(value: string): string {
    return value
      .trim()
      .toLowerCase()
      .replace(/[ً-ْ]/g, '') // Arabic diacritics
      .replace(/[أإآ]/g, 'ا')
      .replace(/[ىي]/g, 'ي')
      .replace(/ة/g, 'ه')
      .replace(/[’'`ـ-]/g, '')
      .replace(/\s+/g, ' ');
  }

  private isValidLatitude(value: number): boolean {
    return Number.isFinite(value) && value >= -90 && value <= 90;
  }

  private isValidLongitude(value: number): boolean {
    return Number.isFinite(value) && value >= -180 && value <= 180;
  }

  /** Catalog cities need no lookup: their coordinates travel in the id. */
  private encodePlaceId(detail: {
    lat: number;
    lng: number;
    label: string;
  }): string {
    const payload = Buffer.from(JSON.stringify(detail), 'utf8').toString(
      'base64url',
    );
    return `osm:${payload}`;
  }

  private decodePlaceId(
    placeId: string,
  ): { lat: number; lng: number; label: string } | null {
    if (!placeId.startsWith('osm:')) return null;
    try {
      const json = Buffer.from(placeId.slice(4), 'base64url').toString('utf8');
      const parsed = JSON.parse(json) as {
        lat?: unknown;
        lng?: unknown;
        label?: unknown;
      };
      const lat = Number(parsed?.lat);
      const lng = Number(parsed?.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
      const label = typeof parsed?.label === 'string' ? parsed.label : '';
      return { lat, lng, label };
    } catch {
      return null;
    }
  }

  /**
   * Parse a query-string coordinate into a finite number. Returns undefined
   * when absent or invalid.
   */
  private coordinate(value?: string): number | undefined {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  async geocode(address: string) {
    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/geocode/json`,
        {
          params: {
            address,
            key: this.googleMapsApiKey,
          },
        },
      );

      if (response.data.status !== 'OK') {
        throw new BadRequestException('Address not found');
      }

      const result = response.data.results[0];
      return {
        latitude: result.geometry.location.lat,
        longitude: result.geometry.location.lng,
        formattedAddress: result.formatted_address,
        placeId: result.place_id,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to geocode address');
    }
  }

  /** Address + country for a point (used for the trip's currency). */
  async reverseGeocode(latitude: number, longitude: number) {
    return this.reverseGeocodeGoogle(latitude, longitude);
  }

  private async googleGeocodeResults(
    latitude: number,
    longitude: number,
    lang: 'ar' | 'en' = 'ar',
  ): Promise<GoogleGeocodeResult[]> {
    const response = await axios.get<{
      status?: string;
      error_message?: string;
      results?: GoogleGeocodeResult[];
    }>(`${this.googleMapsBaseUrl}/geocode/json`, {
      params: {
        latlng: `${latitude},${longitude}`,
        language: lang,
        key: this.googleMapsApiKey,
      },
      timeout: this.providerTimeoutMs,
    });
    const status = response.data?.status;
    if (status === 'ZERO_RESULTS') return [];
    if (status !== 'OK') {
      throw new Error(
        `${status ?? 'UNKNOWN'}: ${response.data?.error_message ?? ''}`,
      );
    }
    return response.data.results ?? [];
  }

  private async reverseGeocodeGoogle(latitude: number, longitude: number) {
    let results: GoogleGeocodeResult[];
    try {
      results = await this.googleGeocodeResults(latitude, longitude);
    } catch (error) {
      this.logger.warn(
        `Google reverse geocode failed: ${this.googleErrorMessage(error)}`,
      );
      throw new BadRequestException('Failed to reverse geocode location');
    }
    const result = results[0];
    if (!result) throw new BadRequestException('Location not found');

    const components = result.address_components ?? [];
    const findComponent = (types: string[]) =>
      components.find((component) =>
        types.every((type) => component.types?.includes(type)),
      );
    const getAddressComponent = (types: string[]) =>
      findComponent(types)?.long_name || '';

    return {
      address: result.formatted_address ?? '',
      city: getAddressComponent(['locality']) || this.cityName(components),
      country: getAddressComponent(['country']),
      // ISO 3166-1 alpha-2 code (e.g. "JO"), used for currency resolution.
      countryCode: findComponent(['country'])?.short_name || '',
    };
  }

  async getDistance(
    fromLatitude: number,
    fromLongitude: number,
    toLatitude: number,
    toLongitude: number,
  ) {
    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/distancematrix/json`,
        {
          params: {
            origins: `${fromLatitude},${fromLongitude}`,
            destinations: `${toLatitude},${toLongitude}`,
            key: this.googleMapsApiKey,
          },
        },
      );

      if (response.data.status !== 'OK') {
        // Say why: a key/billing/API restriction shows up here as
        // REQUEST_DENIED with Google's own message.
        this.logger.warn(
          `Distance Matrix failed with status=${response.data.status}, message=${response.data.error_message ?? 'n/a'}`,
        );
        throw new BadRequestException('Failed to calculate distance');
      }

      const element = response.data.rows[0].elements[0];
      if (element.status !== 'OK') {
        this.logger.warn(
          `Distance Matrix element status=${element.status} for ${fromLatitude},${fromLongitude} → ${toLatitude},${toLongitude}`,
        );
        throw new BadRequestException('Failed to calculate distance');
      }

      return {
        distanceKm: element.distance.value / 1000,
        distanceText: element.distance.text,
        durationMinutes: Math.ceil(element.duration.value / 60),
        durationText: element.duration.text,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      // Network error, timeout, or no key configured.
      this.logger.warn(
        `Distance Matrix request failed: ${(error as Error)?.message ?? error}`,
      );
      throw new BadRequestException('Failed to calculate distance');
    }
  }

  async getRoute(
    fromLatitude: number,
    fromLongitude: number,
    toLatitude: number,
    toLongitude: number,
  ) {
    if (!this.googleMapsApiKey) {
      this.logger.warn(
        'Google Maps API key is not configured. Falling back to OSRM for route generation.',
      );
      return this.getRouteFromOsrm(
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
      );
    }

    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/directions/json`,
        {
          params: {
            origin: `${fromLatitude},${fromLongitude}`,
            destination: `${toLatitude},${toLongitude}`,
            key: this.googleMapsApiKey,
            language: 'ar',
          },
        },
      );

      if (response.data.status !== 'OK') {
        const providerStatus = response.data.status ?? 'UNKNOWN';
        const providerMessage =
          response.data.error_message ?? 'No error message';
        this.logger.warn(
          `Directions API failed with status=${providerStatus}, message=${providerMessage}. Falling back to OSRM.`,
        );
        return this.getRouteFromOsrm(
          fromLatitude,
          fromLongitude,
          toLatitude,
          toLongitude,
        );
      }

      const route = response.data.routes?.[0];
      const leg = route?.legs?.[0];
      const overviewPolyline = route?.overview_polyline?.points;

      if (!route || !leg || !overviewPolyline) {
        this.logger.warn(
          'Directions API returned OK without a usable route payload. Falling back to OSRM.',
        );
        return this.getRouteFromOsrm(
          fromLatitude,
          fromLongitude,
          toLatitude,
          toLongitude,
        );
      }

      return {
        overviewPolyline,
        distanceText: leg.distance?.text ?? '',
        durationText: leg.duration?.text ?? '',
        distanceMeters:
          typeof leg.distance?.value === 'number' ? leg.distance.value : null,
        durationSeconds:
          typeof leg.duration?.value === 'number' ? leg.duration.value : null,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      this.logger.error(
        'Unexpected Google Directions error. Falling back to OSRM.',
        error as Error,
      );
      return this.getRouteFromOsrm(
        fromLatitude,
        fromLongitude,
        toLatitude,
        toLongitude,
      );
    }
  }

  private async getRouteFromOsrm(
    fromLatitude: number,
    fromLongitude: number,
    toLatitude: number,
    toLongitude: number,
  ) {
    try {
      const response = await axios.get(
        `${this.osrmBaseUrl}/route/v1/driving/${fromLongitude},${fromLatitude};${toLongitude},${toLatitude}`,
        {
          params: {
            overview: 'full',
            geometries: 'polyline',
            steps: false,
          },
        },
      );

      if (response.data.code !== 'Ok') {
        const code = response.data.code ?? 'UNKNOWN';
        const message = response.data.message ?? 'No error message';
        throw new BadRequestException(
          `Failed to load route: OSRM ${code} - ${message}`,
        );
      }

      const route = response.data.routes?.[0];
      if (!route?.geometry) {
        throw new BadRequestException(
          'Failed to load route: OSRM empty route payload',
        );
      }

      return {
        overviewPolyline: route.geometry,
        distanceText: this.formatDistanceKm(route.distance),
        durationText: this.formatDurationMinutes(route.duration),
        distanceMeters:
          typeof route.distance === 'number' ? route.distance : null,
        durationSeconds:
          typeof route.duration === 'number'
            ? Math.round(route.duration)
            : null,
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      this.logger.error('OSRM route fallback failed', error as Error);
      throw new BadRequestException('Failed to load route');
    }
  }

  private formatDistanceKm(distanceMeters?: number) {
    if (typeof distanceMeters !== 'number') return '';

    const distanceKm = distanceMeters / 1000;
    return distanceKm >= 10
      ? `${distanceKm.toFixed(0)} كم`
      : `${distanceKm.toFixed(1)} كم`;
  }

  private formatDurationMinutes(durationSeconds?: number) {
    if (typeof durationSeconds !== 'number') return '';

    const minutes = Math.max(1, Math.round(durationSeconds / 60));
    if (minutes < 60) {
      return `${minutes} دقيقة`;
    }

    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return `${hours} ساعة`;
    }

    return `${hours} ساعة ${remainingMinutes} دقيقة`;
  }

  private async assertWithinRateLimit(userId: string) {
    const verdict = await this.rateLimiter.consume(userId);
    if (!verdict.allowed) {
      // `Retry-After` lets the app back off for exactly the right window
      // instead of guessing, as the search screen's 429 handling expects.
      throw new HttpException(
        'Too many location requests',
        HttpStatus.TOO_MANY_REQUESTS,
        { description: `Retry-After: ${verdict.retryAfterSeconds}` },
      );
    }
  }

  /**
   * Short-circuit calls while the provider is failing so a broken upstream
   * fails fast (the app falls back to picking on the map) instead of making
   * every keystroke wait for a timeout.
   */
  private assertProviderAvailable() {
    if (Date.now() < this.breakerOpenUntil) {
      throw new BadGatewayException('Places provider unavailable');
    }
  }

  private recordProviderSuccess() {
    this.providerFailures = 0;
    this.breakerOpenUntil = 0;
  }

  private recordProviderFailure() {
    this.providerFailures += 1;
    if (this.providerFailures >= this.breakerThreshold) {
      this.breakerOpenUntil = Date.now() + this.breakerCooldownMs;
      this.providerFailures = 0;
      this.logger.warn(
        `Places provider breaker opened for ${this.breakerCooldownMs}ms`,
      );
    }
  }

  /** Cache-key fragment for the resolved search context. */
  private contextKey(context?: SearchContext) {
    if (!context) return 'none';
    // ~1 km buckets: nearby users share a cache entry without the bias drifting
    // far enough to change which results are nearest.
    return `${context.lat.toFixed(2)},${context.lng.toFixed(2)}`;
  }

  private getCached<T>(cache: Map<string, CacheEntry<T>>, key: string) {
    const entry = cache.get(key);
    if (!entry) return undefined;

    if (entry.expiresAt <= Date.now()) {
      cache.delete(key);
      return undefined;
    }

    return entry.value;
  }

  private setCached<T>(
    cache: Map<string, CacheEntry<T>>,
    key: string,
    value: T,
  ) {
    this.evictIfFull(cache);
    cache.set(key, { value, expiresAt: Date.now() + this.cacheTtlMs });
  }

  /**
   * Keep the in-process caches bounded. Drops expired entries first and, if
   * that is not enough, the oldest inserted keys — Map preserves insertion
   * order, so the first keys are the ones written longest ago.
   */
  private evictIfFull<T>(cache: Map<string, CacheEntry<T>>) {
    if (cache.size < this.cacheMaxEntries) return;

    const now = Date.now();
    for (const [key, entry] of cache) {
      if (entry.expiresAt <= now) cache.delete(key);
    }

    let overflow = cache.size - this.cacheMaxEntries + 1;
    if (overflow <= 0) return;
    for (const key of cache.keys()) {
      cache.delete(key);
      if (--overflow <= 0) break;
    }
  }
}
