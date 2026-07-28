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

type CacheEntry<T> = {
  expiresAt: number;
  value: T;
};

type RateEntry = {
  windowStartedAt: number;
  count: number;
};

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
}

interface PhotonFeature {
  geometry?: { coordinates?: number[] };
  properties?: PhotonProperties;
}

interface PhotonResponse {
  features?: PhotonFeature[];
}

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
  private readonly rateLimits = new Map<string, RateEntry>();
  private readonly cacheTtlMs = 60_000;
  private readonly rateWindowMs = 60_000;
  private readonly rateLimitPerWindow = 60;

  constructor(private configService: ConfigService) {
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

    this.assertWithinRateLimit(userId);

    const lang = query.lang === 'en' ? 'en' : 'ar';
    const cacheKey = [
      q.toLowerCase(),
      lang,
      this.autocompleteCountries.join(','),
      this.locationBiasKey(query.lat, query.lng),
    ].join('|');
    const cached = this.getCached(this.autocompleteCache, cacheKey);
    if (cached) {
      return { sessionToken, suggestions: cached };
    }

    try {
      const lat = this.coordinate(query.lat);
      const lng = this.coordinate(query.lng);
      const response = await axios.get<PhotonResponse>(
        `${this.photonBaseUrl}/api/`,
        {
          params: {
            q,
            limit: 6,
            // Photon only localizes output for a few languages; for Arabic we
            // omit `lang` so it returns the native (Arabic) place names.
            lang: lang === 'en' ? 'en' : undefined,
            lat,
            lon: lng,
          },
          headers: { 'User-Agent': this.geocoderUserAgent },
          timeout: 8000,
        },
      );

      const features = response.data?.features ?? [];
      const suggestions = features
        .filter((feature) => this.matchesCountryFilter(feature))
        .map((feature): PlaceSuggestionDto => this.toSuggestion(feature))
        .filter((suggestion) => suggestion.placeId)
        .slice(0, 6);

      this.setCached(this.autocompleteCache, cacheKey, suggestions);
      return { sessionToken, suggestions };
    } catch {
      this.logger.warn('Photon autocomplete request failed');
      throw new BadGatewayException('Places provider unavailable');
    }
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
  private toSuggestion(feature: PhotonFeature): PlaceSuggestionDto {
    const empty: PlaceSuggestionDto = {
      placeId: '',
      primaryText: '',
      secondaryText: '',
      description: '',
    };

    const coordinates = feature.geometry?.coordinates;
    if (!Array.isArray(coordinates) || coordinates.length < 2) return empty;
    const lng = Number(coordinates[0]);
    const lat = Number(coordinates[1]);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return empty;

    const props = feature.properties ?? {};
    const primaryText = (props.name ?? props.street ?? '').trim();
    if (!primaryText) return empty;

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

    const secondaryText = secondaryParts.join('، ');
    const description = [primaryText, ...secondaryParts].join('، ');

    return {
      placeId: this.encodePlaceId({ lat, lng, label: description }),
      primaryText,
      secondaryText,
      description,
    };
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

  private assertWithinRateLimit(userId: string) {
    const now = Date.now();
    const current = this.rateLimits.get(userId);
    if (!current || now - current.windowStartedAt > this.rateWindowMs) {
      this.rateLimits.set(userId, { windowStartedAt: now, count: 1 });
      return;
    }

    current.count += 1;
    if (current.count > this.rateLimitPerWindow) {
      throw new HttpException(
        'Too many location requests',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }

  private locationBias(lat?: string, lng?: string) {
    const latitude = Number(lat);
    const longitude = Number(lng);
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return undefined;
    }

    return `${latitude},${longitude}`;
  }

  private locationBiasKey(lat?: string, lng?: string) {
    return this.locationBias(lat, lng) ?? 'none';
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
    cache.set(key, { value, expiresAt: Date.now() + this.cacheTtlMs });
  }
}
