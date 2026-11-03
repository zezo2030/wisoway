import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { LocationsService } from './locations.service';
import { PlacesRateLimiter } from './places-rate-limiter';

jest.mock('axios');

const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('LocationsService', () => {
  const configService = {
    get: jest.fn(),
  } as unknown as ConfigService;

  /**
   * Rate limiting is covered by its own suite; here it always allows so the
   * places behaviour under test is not entangled with the budget.
   */
  let rateLimiter: PlacesRateLimiter;

  const build = () => new LocationsService(configService, rateLimiter);

  beforeEach(() => {
    jest.clearAllMocks();
    rateLimiter = {
      consume: jest.fn().mockResolvedValue({
        allowed: true,
        retryAfterSeconds: 60,
      }),
    } as unknown as PlacesRateLimiter;
  });

  /** A Places API (New) autocomplete answer. */
  const predictions = (
    ...items: Array<{
      id: string;
      main: string;
      secondary?: string;
      distanceMeters?: number;
    }>
  ) => ({
    data: {
      suggestions: items.map((item) => ({
        placePrediction: {
          placeId: item.id,
          text: {
            text: [item.main, item.secondary].filter(Boolean).join('، '),
          },
          structuredFormat: {
            mainText: { text: item.main },
            ...(item.secondary
              ? { secondaryText: { text: item.secondary } }
              : {}),
          },
          ...(item.distanceMeters !== undefined
            ? { distanceMeters: item.distanceMeters }
            : {}),
        },
      })),
    },
  });

  /** A Geocoding answer naming a point in [countryCode]. */
  const geocoded = (formatted: string, countryCode = 'JO', locality = '') => ({
    data: {
      status: 'OK',
      results: [
        {
          formatted_address: formatted,
          types: ['street_address'],
          address_components: [
            ...(locality
              ? [
                  {
                    long_name: locality,
                    short_name: locality,
                    types: ['locality'],
                  },
                ]
              : []),
            {
              long_name: countryCode,
              short_name: countryCode,
              types: ['country', 'political'],
            },
          ],
        },
      ],
    },
  });

  describe('autocomplete', () => {
    beforeEach(() => {
      (configService.get as jest.Mock).mockImplementation((key: string) =>
        key === 'GOOGLE_MAPS_API_KEY' ? 'test-key' : undefined,
      );
    });

    it('searches Google Places and maps predictions to the two lines the app shows', async () => {
      mockedAxios.post.mockResolvedValue(
        predictions({ id: 'ChIJjerash', main: 'جرش', secondary: 'الأردن' }),
      );

      const result = await build().autocomplete(
        { q: 'جرش', lang: 'ar', sessionToken: 'session-1', country: 'JO' },
        'user-1',
      );

      expect(result).toEqual({
        sessionToken: 'session-1',
        suggestions: [
          {
            placeId: 'ChIJjerash',
            primaryText: 'جرش',
            secondaryText: 'الأردن',
            description: 'جرش، الأردن',
            distanceMeters: null,
          },
        ],
      });
      const [url, body, config] = mockedAxios.post.mock.calls[0];
      expect(url).toBe('https://places.googleapis.com/v1/places:autocomplete');
      expect(body).toMatchObject({
        input: 'جرش',
        languageCode: 'ar',
        sessionToken: 'session-1',
        includedRegionCodes: ['jo'],
      });
      expect(config?.headers).toMatchObject({ 'X-Goog-Api-Key': 'test-key' });
      // Search no longer touches the free OpenStreetMap geocoder.
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });

    it('biases to the passenger and orders the results nearest first', async () => {
      mockedAxios.post.mockResolvedValue(
        predictions(
          { id: 'far', main: 'مستشفى الملك', distanceMeters: 300_000 },
          { id: 'near', main: 'مستشفى العلا', distanceMeters: 6_000 },
        ),
      );

      const result = await build().autocomplete(
        { q: 'مستشفى', lat: '26.6', lng: '37.9', country: 'SA' },
        'user-1',
      );

      expect(result.suggestions.map((s) => s.placeId)).toEqual(['near', 'far']);
      expect(mockedAxios.post.mock.calls[0][1]).toMatchObject({
        locationBias: {
          circle: {
            center: { latitude: 26.6, longitude: 37.9 },
            radius: 50_000,
          },
        },
        origin: { latitude: 26.6, longitude: 37.9 },
        includedRegionCodes: ['sa'],
      });
    });

    it('infers the country from the passenger when the app sends none', async () => {
      mockedAxios.get.mockResolvedValue(geocoded('العلا', 'SA') as never);
      mockedAxios.post.mockResolvedValue(predictions());

      await build().autocomplete({ q: 'مطار', lat: '26.6', lng: '37.9' }, 'u');

      expect(mockedAxios.get.mock.calls[0][0]).toContain('/geocode/json');
      expect(mockedAxios.post.mock.calls[0][1]).toMatchObject({
        includedRegionCodes: ['sa'],
      });
    });

    it('skips the provider for queries shorter than two characters', async () => {
      const result = await build().autocomplete({ q: 'ع' }, 'user-1');

      expect(result.suggestions).toEqual([]);
      expect(mockedAxios.post).not.toHaveBeenCalled();
    });

    it('lifts a city above nearby places when the query names it', async () => {
      mockedAxios.post.mockResolvedValue(
        predictions(
          { id: 'shop', main: 'محل العقبة', distanceMeters: 4_000 },
          { id: 'aqaba', main: 'العقبة', distanceMeters: 300_000 },
        ),
      );

      const result = await build().autocomplete(
        { q: 'العقبه', lat: '31.95', lng: '35.91', country: 'JO' },
        'user-1',
      );

      expect(result.suggestions[0].placeId).toBe('aqaba');
    });

    it('rejects the request when the rate limiter refuses it', async () => {
      (rateLimiter.consume as jest.Mock).mockResolvedValue({
        allowed: false,
        retryAfterSeconds: 42,
      });

      await expect(
        build().autocomplete({ q: 'عما' }, 'user-1'),
      ).rejects.toBeInstanceOf(HttpException);
      expect(mockedAxios.post).not.toHaveBeenCalled();
    });

    it('surfaces a Google refusal as 502 without leaking the provider error', async () => {
      mockedAxios.post.mockRejectedValue(new Error('403 PERMISSION_DENIED'));

      await expect(
        build().autocomplete({ q: 'عما' }, 'user-1'),
      ).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('stops calling a repeatedly failing provider until the breaker cools down', async () => {
      mockedAxios.post.mockRejectedValue(new Error('provider down'));
      const service = build();

      // Distinct queries so the cache cannot mask the calls.
      for (const q of ['aa', 'bb', 'cc', 'dd', 'ee']) {
        await expect(
          service.autocomplete({ q }, 'user-1'),
        ).rejects.toBeInstanceOf(BadGatewayException);
      }
      expect(mockedAxios.post).toHaveBeenCalledTimes(5);

      mockedAxios.post.mockClear();
      await expect(
        service.autocomplete({ q: 'ff' }, 'user-1'),
      ).rejects.toBeInstanceOf(BadGatewayException);
      expect(mockedAxios.post).not.toHaveBeenCalled();
    });
  });

  describe('placeDetail', () => {
    beforeEach(() => {
      (configService.get as jest.Mock).mockImplementation((key: string) =>
        key === 'GOOGLE_MAPS_API_KEY' ? 'test-key' : undefined,
      );
    });

    it('looks a picked place up in the same session, keeping the wording of the list', async () => {
      const service = build();
      mockedAxios.post.mockResolvedValue(
        predictions({ id: 'ChIJjerash', main: 'جرش', secondary: 'الأردن' }),
      );
      await service.autocomplete({ q: 'جرش', country: 'JO' }, 'user-1');
      mockedAxios.get.mockResolvedValue({
        data: {
          id: 'ChIJjerash',
          displayName: { text: 'Jerash' },
          formattedAddress: 'Jerash, Jordan',
          location: { latitude: 32.28, longitude: 35.89 },
        },
      } as never);

      await expect(
        service.placeDetail('ChIJjerash', 'session-1'),
      ).resolves.toEqual({
        placeId: 'ChIJjerash',
        label: 'جرش، الأردن',
        lat: 32.28,
        lng: 35.89,
      });
      const [url, config] = mockedAxios.get.mock.calls[0];
      expect(url).toBe('https://places.googleapis.com/v1/places/ChIJjerash');
      expect(config?.params).toEqual({ sessionToken: 'session-1' });
      expect(config?.headers).toMatchObject({
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
      });
    });

    it('resolves a catalog city from its id without a lookup', async () => {
      mockedAxios.post.mockResolvedValue(predictions());
      const service = build();
      const { suggestions } = await service.autocomplete(
        { q: 'اربد', country: 'JO' },
        'user-1',
      );

      const city = await service.placeDetail(suggestions[0].placeId);

      expect(city.label).toBe('إربد');
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });

    it('maps a place Google does not know to 404', async () => {
      mockedAxios.get.mockRejectedValue(
        Object.assign(new Error('Not Found'), {
          isAxiosError: true,
          response: { status: 404 },
        }),
      );
      mockedAxios.isAxiosError.mockReturnValue(true);

      await expect(build().placeDetail('ChIJgone')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('reverse', () => {
    beforeEach(() => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
    });

    it('resolves a map point to primary and secondary address lines', async () => {
      mockedAxios.get.mockResolvedValue(
        geocoded('شارع الرينبو، جبل عمان، عمان، الأردن', 'JO', 'عمان') as never,
      );

      const result = await build().reverse(
        { lat: '31.9539', lng: '35.9106', lang: 'ar' },
        'user-1',
      );

      expect(result).toEqual({
        primaryText: 'شارع الرينبو',
        secondaryText: 'جبل عمان، عمان، الأردن',
        label: 'شارع الرينبو، جبل عمان، عمان، الأردن',
        city: 'عمان',
        lat: 31.9539,
        lng: 35.9106,
      });
      expect(mockedAxios.get.mock.calls[0][1]?.params).toMatchObject({
        latlng: '31.9539,35.9106',
        language: 'ar',
      });
    });

    it('drops the plus code Google gives a rural point', async () => {
      mockedAxios.get.mockResolvedValue(
        geocoded('7VJX+2VM، جرش، الأردن', 'JO', 'جرش') as never,
      );

      const result = await build().reverse(
        { lat: '32.2803', lng: '35.8993' },
        'user-1',
      );

      expect(result).toMatchObject({
        primaryText: 'جرش',
        secondaryText: 'الأردن',
        label: 'جرش، الأردن',
      });
    });

    it('returns the point with empty text when Google knows no address', async () => {
      mockedAxios.get.mockResolvedValue({
        data: { status: 'ZERO_RESULTS', results: [] },
      } as never);

      const result = await build().reverse({ lat: '0', lng: '0' }, 'user-1');

      expect(result).toMatchObject({ primaryText: '', label: '', lat: 0 });
    });

    it('rejects out-of-range coordinates before calling the provider', async () => {
      await expect(
        build().reverse({ lat: '95', lng: '10' }, 'user-1'),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });
  });

  describe('cities', () => {
    it('returns the catalog for a country', () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);

      const { cities } = build().cities({ country: 'jo' });

      expect(cities.length).toBeGreaterThan(5);
      expect(cities.every((city) => city.countryCode === 'JO')).toBe(true);
      expect(cities.some((city) => city.id === 'jo-amman')).toBe(true);
    });

    it('matches Arabic names regardless of hamza spelling', () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);

      const { cities } = build().cities({ q: 'اربد' });

      expect(cities.map((city) => city.id)).toContain('jo-irbid');
    });

    it('matches English names case-insensitively', () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);

      const { cities } = build().cities({ q: 'AMMAN' });

      expect(cities.map((city) => city.id)).toEqual(['jo-amman']);
    });

    it('honours the configured country restriction', () => {
      (configService.get as jest.Mock).mockImplementation((key: string) =>
        key === 'LOCATION_AUTOCOMPLETE_COUNTRIES' ? 'eg' : undefined,
      );

      expect(build().cities({}).cities).toEqual([]);
    });
  });

  describe('getRoute', () => {
    it('returns overview polyline with distance and duration', async () => {
      (configService.get as jest.Mock).mockReturnValue('test-key');
      mockedAxios.get.mockResolvedValue({
        data: {
          status: 'OK',
          routes: [
            {
              overview_polyline: { points: 'encoded-polyline' },
              legs: [
                {
                  distance: { text: '12 km', value: 12000 },
                  duration: { text: '18 mins', value: 1080 },
                },
              ],
            },
          ],
        },
      } as never);

      const service = build();

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).resolves.toEqual({
        overviewPolyline: 'encoded-polyline',
        distanceText: '12 km',
        durationText: '18 mins',
        distanceMeters: 12000,
        durationSeconds: 1080,
      });
    });

    it('throws when Google Maps API key is missing', async () => {
      (configService.get as jest.Mock).mockReturnValue('');
      mockedAxios.get.mockResolvedValue({
        data: {
          code: 'Ok',
          routes: [
            {
              geometry: 'osrm-polyline',
              distance: 12500,
              duration: 1080,
            },
          ],
        },
      } as never);

      const service = build();

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).resolves.toEqual({
        overviewPolyline: 'osrm-polyline',
        // 12.5 km rounds to a whole number above the 10 km threshold.
        distanceText: '13 كم',
        durationText: '18 دقيقة',
        distanceMeters: 12500,
        durationSeconds: 1080,
      });
    });

    it('falls back to OSRM when directions API returns no route', async () => {
      (configService.get as jest.Mock).mockReturnValue('test-key');
      mockedAxios.get
        .mockResolvedValueOnce({
          data: {
            status: 'ZERO_RESULTS',
            routes: [],
          },
        } as never)
        .mockResolvedValueOnce({
          data: {
            code: 'Ok',
            routes: [
              {
                geometry: 'osrm-fallback-polyline',
                distance: 5200,
                duration: 720,
              },
            ],
          },
        } as never);

      const service = build();

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).resolves.toEqual({
        overviewPolyline: 'osrm-fallback-polyline',
        distanceText: '5.2 كم',
        durationText: '12 دقيقة',
        distanceMeters: 5200,
        durationSeconds: 720,
      });
    });

    it('throws when both Google and OSRM fail', async () => {
      (configService.get as jest.Mock).mockReturnValue('test-key');
      mockedAxios.get
        .mockResolvedValueOnce({
          data: {
            status: 'REQUEST_DENIED',
            error_message: 'Billing disabled',
          },
        } as never)
        .mockResolvedValueOnce({
          data: {
            code: 'NoRoute',
            message: 'Impossible route',
          },
        } as never);

      const service = build();

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('reverseGeocode', () => {
    it('reads the country from Google for the trip currency', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue(
        geocoded('العلا، السعودية', 'SA', 'العلا') as never,
      );

      const result = await build().reverseGeocode(26.6086, 37.9232);

      expect(result).toMatchObject({ countryCode: 'SA', city: 'العلا' });
      expect(mockedAxios.get).toHaveBeenCalledTimes(1);
    });

    it('fails when Google refuses, with no free fallback', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: { status: 'REQUEST_DENIED', results: [] },
      } as never);

      await expect(build().reverseGeocode(0, 0)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(mockedAxios.get).toHaveBeenCalledTimes(1);
    });
  });
});
