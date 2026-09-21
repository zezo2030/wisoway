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

/** Subset of a Photon GeoJSON feature's address properties we consume. */
interface PhotonProperties {
  name?: string;
  street?: string;
  district?: string;
  city?: string;
  county?: string;
  state?: string;
  country?: string;
  countrycode?: string;
  /** OSM identity, used to deduplicate the same place across query variants. */
  osm_type?: string;
  osm_id?: number;
  /** OSM classification, used to push transit furniture below real places. */
  osm_key?: string;
  osm_value?: string;
}

interface PhotonFeature {
  geometry?: { coordinates?: number[] };
  properties?: PhotonProperties;
}

interface PhotonResponse {
  features?: PhotonFeature[];
}

/**
 * OSM classifications that are technically named places but almost never what
 * someone searching for a pickup point means.
 *
 * Measured on a Jordanian sample: searching "الجامعة الاردنية" returned the
 * bus stop *outside* the university above the university itself. These are
 * demoted rather than dropped, so a user who really did search for a bus stop
 * can still find one.
 */
const DEMOTED_OSM_TYPES = new Set<string>([
  'highway:bus_stop',
  'highway:crossing',
  'highway:traffic_signals',
  'highway:turning_circle',
  'highway:stop',
  'highway:give_way',
  'public_transport:platform',
  'public_transport:stop_position',
  'amenity:bench',
  'amenity:waste_basket',
  'amenity:shelter',
]);

@Injectable()
export class LocationsService {
  private readonly logger = new Logger(LocationsService.name);
  private readonly googleMapsApiKey: string;
  private readonly googleMapsBaseUrl = 'https://maps.googleapis.com/maps/api';
  private readonly osrmBaseUrl = 'https://router.project-osrm.org';
  /**
   * Free OpenStreetMap-based Photon geocoder used for place autocomplete +
   * detail so the inDrive-style type-ahead works without a billed Google
   * Places key. Photon is purpose-built for prefix/type-ahead search (unlike
   * Nominatim, which only matches whole words) and indexes Arabic names well.
   * Defaults to the public instance; set PHOTON_BASE_URL to a self-hosted
   * mirror to lift the public instance's rate limits.
   */
  private readonly photonBaseUrl: string;
  private readonly geocoderUserAgent: string;
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
  /**
   * Suggestions returned to the app. Photon has no country/city restriction
   * parameter, so we over-fetch and filter down to this many locally.
   */
  private readonly suggestionLimit = 6;
  private readonly providerFetchLimit = 15;

  constructor(
    private configService: ConfigService,
    private readonly rateLimiter: PlacesRateLimiter,
  ) {
    this.googleMapsApiKey = this.configService.get<string>(
      'GOOGLE_MAPS_API_KEY',
      '',
    );
    this.photonBaseUrl = (
      this.configService.get<string>('PHOTON_BASE_URL') ||
      'https://photon.komoot.io'
    ).replace(/\/+$/, '');
    // OSM geocoders ask for an identifiable User-Agent header (app + contact).
    this.geocoderUserAgent =
      this.configService.get<string>('GEOCODER_USER_AGENT') ||
      'WisowayRideshare/1.0 (+https://wisoway.app)';
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
    const cacheKey = [
      q.toLowerCase(),
      lang,
      this.autocompleteCountries.join(','),
      context?.city?.id ?? '-',
      this.contextKey(context),
    ].join('|');
    const cached = this.getCached(this.autocompleteCache, cacheKey);
    if (cached) {
      return { sessionToken, suggestions: cached };
    }

    this.assertProviderAvailable();

    try {
      const features = await this.searchPhoton(q, lang, context);
      this.recordProviderSuccess();

      const ranked = this.rankSuggestions(
        features
          .filter((feature) => this.matchesCountryFilter(feature))
          .map((feature) => ({
            suggestion: this.toSuggestion(feature, context),
            demoted: this.isDemotedType(feature),
          }))
          .filter((entry) => entry.suggestion.placeId),
        context,
      );
      const suggestions = this.promoteCityMatches(ranked, q, context).slice(
        0,
        this.suggestionLimit,
      );

      this.setCached(this.autocompleteCache, cacheKey, suggestions);
      return { sessionToken, suggestions };
    } catch (error) {
      this.recordProviderFailure();
      this.logger.warn(
        `Photon autocomplete request failed: ${
          (error as Error)?.message ?? 'unknown error'
        }`,
      );
      throw new BadGatewayException('Places provider unavailable');
    }
  }

  /**
   * Run the query against Photon once per spelling variant and merge.
   *
   * Arabic input varies in ways the index does not. Measured on a Jordanian
   * sample: "الجامعة الاردنية" spelled correctly returned the university's bus
   * stop but not the university, while the same words with ه for ة returned it
   * first; and "اربد" typed without its hamza missed the city entirely.
   * Searching the variants alongside the raw text recovers both.
   *
   * The raw query decides success. Variants are best-effort, so one failing
   * variant can never turn a working search into an error.
   */
  private async searchPhoton(
    q: string,
    lang: 'ar' | 'en',
    context?: SearchContext,
  ): Promise<PhotonFeature[]> {
    const forms = this.queryVariants(q);
    const settled = await Promise.allSettled(
      forms.map((form) => this.photonRequest(form, lang, context)),
    );

    const raw = settled[0];
    if (raw.status === 'rejected') {
      throw raw.reason instanceof Error
        ? raw.reason
        : new Error(String(raw.reason));
    }

    return this.mergeFeatureLists(
      settled
        .filter(
          (entry): entry is PromiseFulfilledResult<PhotonFeature[]> =>
            entry.status === 'fulfilled',
        )
        .map((entry) => entry.value),
    );
  }

  private async photonRequest(
    q: string,
    lang: 'ar' | 'en',
    context?: SearchContext,
  ): Promise<PhotonFeature[]> {
    const response = await axios.get<PhotonResponse>(
      `${this.photonBaseUrl}/api/`,
      {
        params: {
          q,
          // Over-fetch: country and city filtering happens locally, so asking
          // for exactly `suggestionLimit` would let a single foreign hit empty
          // the list.
          limit: this.providerFetchLimit,
          // Photon only localizes output for a few languages; for Arabic we
          // omit `lang` so it returns the native (Arabic) place names.
          lang: lang === 'en' ? 'en' : undefined,
          lat: context?.lat,
          lon: context?.lng,
          // Weight proximity heavily so the provider's candidate set is
          // already local; the final nearest-first order is applied here.
          location_bias_scale: context ? 0.8 : undefined,
        },
        headers: { 'User-Agent': this.geocoderUserAgent },
        timeout: this.providerTimeoutMs,
      },
    );
    return response.data?.features ?? [];
  }

  /**
   * Arabic spelling variants worth searching alongside the text as typed.
   *
   * Returns the raw query first; callers rely on that ordering. Most queries
   * produce no variant at all, so the extra request only happens when the
   * spelling is actually ambiguous.
   */
  private queryVariants(q: string): string[] {
    const variants = [q];

    // Users routinely type ه for ة and ي for ى.
    const taMarbuta = q.replace(/ة/g, 'ه').replace(/ى/g, 'ي');
    if (taMarbuta !== q) variants.push(taMarbuta);

    // A word-initial bare alef is often a dropped hamza ("اربد" → "إربد").
    // The definite article "ال" is excluded: "إلجامعة" is not a word.
    const hamza = q.replace(/(^|\s)ا(?!ل)/g, '$1إ');
    if (hamza !== q) variants.push(hamza);

    return [...new Set(variants)];
  }

  /**
   * Interleave the per-variant result lists so no single spelling owns the
   * head of the list, dropping places already contributed by an earlier list.
   */
  private mergeFeatureLists(lists: PhotonFeature[][]): PhotonFeature[] {
    if (lists.length === 1) return lists[0];

    const seen = new Set<string>();
    const merged: PhotonFeature[] = [];
    const depth = Math.max(...lists.map((list) => list.length), 0);

    for (let index = 0; index < depth; index++) {
      for (const list of lists) {
        const feature = list[index];
        if (!feature) continue;
        const id = this.featureKey(feature);
        if (id && seen.has(id)) continue;
        if (id) seen.add(id);
        merged.push(feature);
      }
    }

    return merged;
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
  ): PlaceSuggestionDto[] {
    if (context?.city) return suggestions;

    const needle = this.normalizeForSearch(q);
    // Two letters match far too many city names to be a useful signal.
    if (needle.length < 3) return suggestions;

    const city = CITY_CATALOG.find(
      (candidate) =>
        this.normalizeForSearch(candidate.nameAr).startsWith(needle) ||
        this.normalizeForSearch(candidate.nameEn).startsWith(needle),
    );
    if (!city) return suggestions;

    const cityName = this.normalizeForSearch(city.nameAr);
    // Name alone is not enough: searching "العقبه" surfaced a same-named place
    // 2,190 km away, which would have been promoted as if it were Aqaba. The
    // match must also sit where the city actually is.
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
   * True when a suggestion lies within the sprawl of a catalog city, using the
   * coordinates carried in its own placeId so no extra lookup is needed.
   */
  private isNearCity(suggestion: PlaceSuggestionDto, city: CityDto): boolean {
    const point = this.decodePlaceId(suggestion.placeId);
    if (!point) return false;
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

  /** OSM identity of a feature, used to deduplicate across query variants. */
  private featureKey(feature: PhotonFeature): string | null {
    const props = feature.properties;
    if (!props?.osm_type || props.osm_id === undefined) return null;
    return `${props.osm_type}:${props.osm_id}`;
  }

  private isDemotedType(feature: PhotonFeature): boolean {
    const props = feature.properties;
    if (!props?.osm_key || !props.osm_value) return false;
    return DEMOTED_OSM_TYPES.has(`${props.osm_key}:${props.osm_value}`);
  }

  /**
   * Resolve a point-on-map to a display address, using the same provider as
   * search so the picker's label matches what the suggestion list would show.
   */
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

    try {
      const response = await axios.get<PhotonResponse>(
        `${this.photonBaseUrl}/reverse`,
        {
          params: {
            lat,
            lon: lng,
            limit: 1,
            lang: lang === 'en' ? 'en' : undefined,
          },
          headers: { 'User-Agent': this.geocoderUserAgent },
          timeout: this.providerTimeoutMs,
        },
      );

      this.recordProviderSuccess();

      const feature = response.data?.features?.[0];
      const texts = feature
        ? this.buildAddressTexts(feature.properties ?? {})
        : { primaryText: '', secondaryText: '', description: '' };

      const result: ReverseGeocodeResponseDto = {
        primaryText: texts.primaryText,
        secondaryText: texts.secondaryText,
        label: texts.description,
        lat,
        lng,
      };
      this.setCached(this.reverseCache, cacheKey, result);
      return result;
    } catch (error) {
      this.recordProviderFailure();
      this.logger.warn(
        `Photon reverse request failed: ${
          (error as Error)?.message ?? 'unknown error'
        }`,
      );
      throw new BadGatewayException('Places provider unavailable');
    }
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
   * Order suggestions the way inDrive does: strictly nearest first. Every
   * suggestion carries its own coordinates, so the sort key is the straight
   * line from the search context (the user's device location). Provider
   * relevance only breaks ties, and decides the whole order when no context
   * was sent.
   */
  private rankSuggestions(
    entries: Array<{ suggestion: PlaceSuggestionDto; demoted: boolean }>,
    context?: SearchContext,
  ): PlaceSuggestionDto[] {
    const distanceOf = (suggestion: PlaceSuggestionDto): number => {
      if (!context) return 0;
      return suggestion.distanceMeters ?? Number.POSITIVE_INFINITY;
    };

    // Transit furniture sinks below every real place, whatever its distance.
    const tier = (entry: { demoted: boolean }) => (entry.demoted ? 1 : 0);

    // `map`+`sort` on the index keeps the sort stable across Node versions,
    // preserving the provider's own relevance order on equal distance.
    return entries
      .map((entry, index) => ({
        entry,
        index,
        tier: tier(entry),
        distance: distanceOf(entry.suggestion),
      }))
      .sort(
        (a, b) =>
          a.tier - b.tier || a.distance - b.distance || a.index - b.index,
      )
      .map(({ entry }) => entry.suggestion);
  }

  /**
   * Photon has no country-restriction parameter, so honour
   * LOCATION_AUTOCOMPLETE_COUNTRIES by filtering on each feature's countrycode.
   */
  private matchesCountryFilter(feature: PhotonFeature): boolean {
    if (this.autocompleteCountries.length === 0) return true;
    const code = (feature.properties?.countrycode ?? '').toLowerCase();
    return code.length === 0 || this.autocompleteCountries.includes(code);
  }

  placeDetail(placeId: string): Promise<PlaceDetailResponseDto> {
    const id = placeId?.trim();
    // Coordinates + label are encoded into the suggestion's placeId, so the
    // lookup is local and needs no second network round-trip.
    const decoded = id ? this.decodePlaceId(id) : null;
    if (!decoded) {
      return Promise.reject(new NotFoundException('Place not found'));
    }

    return Promise.resolve({
      placeId: id,
      label: decoded.label,
      lat: decoded.lat,
      lng: decoded.lng,
    });
  }

  /**
   * Map a single Photon GeoJSON feature to the suggestion shape the app
   * expects, packing the resolved coordinates into the placeId.
   */
  private toSuggestion(
    feature: PhotonFeature,
    context?: SearchContext,
  ): PlaceSuggestionDto {
    const empty: PlaceSuggestionDto = {
      placeId: '',
      primaryText: '',
      secondaryText: '',
      description: '',
      distanceMeters: null,
    };

    const coordinates = feature.geometry?.coordinates;
    if (!Array.isArray(coordinates) || coordinates.length < 2) return empty;
    const lng = Number(coordinates[0]);
    const lat = Number(coordinates[1]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return empty;

    const texts = this.buildAddressTexts(feature.properties ?? {});
    if (!texts.primaryText) return empty;

    return {
      placeId: this.encodePlaceId({ lat, lng, label: texts.description }),
      primaryText: texts.primaryText,
      secondaryText: texts.secondaryText,
      description: texts.description,
      // Photon returns coordinates with every suggestion, so the distance
      // label costs no extra request — no per-row place-details lookup.
      distanceMeters: context
        ? Math.round(this.haversineMeters(context.lat, context.lng, lat, lng))
        : null,
    };
  }

  /**
   * Split a Photon feature's address properties into the two lines the app
   * renders: a bold place name and a grey street/district/city line. Shared by
   * autocomplete and reverse geocoding so both read identically.
   */
  private buildAddressTexts(props: PhotonProperties): {
    primaryText: string;
    secondaryText: string;
    description: string;
  } {
    const primaryText = (props.name ?? props.street ?? '').trim();
    if (!primaryText) {
      return { primaryText: '', secondaryText: '', description: '' };
    }

    // Build the secondary line from the surrounding address parts, dropping any
    // that repeat the primary text or each other.
    const seen = new Set<string>([primaryText]);
    const secondaryParts: string[] = [];
    for (const value of [
      props.street,
      props.district,
      props.city,
      props.county,
      props.state,
      props.country,
    ]) {
      const part = (value ?? '').trim();
      if (part && !seen.has(part)) {
        seen.add(part);
        secondaryParts.push(part);
      }
    }

    return {
      primaryText,
      secondaryText: secondaryParts.join('، '),
      description: [primaryText, ...secondaryParts].join('، '),
    };
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
   * Parse a query-string coordinate into a finite number, biasing Photon
   * results toward the user. Returns undefined when absent or invalid.
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

  async reverseGeocode(latitude: number, longitude: number) {
    try {
      const response = await axios.get(
        `${this.googleMapsBaseUrl}/geocode/json`,
        {
          params: {
            latlng: `${latitude},${longitude}`,
            key: this.googleMapsApiKey,
          },
        },
      );

      if (response.data.status !== 'OK') {
        throw new BadRequestException('Location not found');
      }

      const result = response.data.results[0];
      const addressComponents = result.address_components;

      const findComponent = (types: string[]) =>
        addressComponents.find((component: any) =>
          types.every((type) => component.types.includes(type)),
        );
      const getAddressComponent = (types: string[]) =>
        findComponent(types)?.long_name || '';

      return {
        address: result.formatted_address,
        city: getAddressComponent(['locality', 'administrative_area_level_2']),
        country: getAddressComponent(['country']),
        // ISO 3166-1 alpha-2 code (e.g. "JO"), used for currency resolution.
        countryCode: findComponent(['country'])?.short_name || '',
      };
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }
      throw new BadRequestException('Failed to reverse geocode location');
    }
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
        throw new BadRequestException('Failed to calculate distance');
      }

      const element = response.data.rows[0].elements[0];
      if (element.status !== 'OK') {
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
