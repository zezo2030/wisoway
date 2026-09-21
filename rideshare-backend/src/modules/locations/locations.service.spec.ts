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

  describe('autocomplete', () => {
    it('maps Photon features into suggestions with a resolvable placeId', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.9106, 31.9539] },
              properties: {
                name: 'عمان',
                state: 'محافظة العاصمة',
                country: 'الأردن',
                countrycode: 'JO',
              },
            },
          ],
        },
      } as never);

      const service = build();

      const result = await service.autocomplete(
        { q: 'عما', lang: 'ar' },
        'user-1',
      );

      expect(result.suggestions).toHaveLength(1);
      const [suggestion] = result.suggestions;
      expect(suggestion.primaryText).toBe('عمان');
      expect(suggestion.secondaryText).toBe('محافظة العاصمة، الأردن');
      expect(suggestion.placeId.startsWith('osm:')).toBe(true);
      // No search context was sent, so there is no distance to show.
      expect(suggestion.distanceMeters).toBeNull();

      // placeId round-trips through placeDetail with no extra network call.
      mockedAxios.get.mockClear();
      const detail = await service.placeDetail(suggestion.placeId);
      expect(detail).toEqual({
        placeId: suggestion.placeId,
        label: 'عمان، محافظة العاصمة، الأردن',
        lat: 31.9539,
        lng: 35.9106,
      });
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });

    it('drops features outside the configured country filter', async () => {
      (configService.get as jest.Mock).mockImplementation((key: string) =>
        key === 'LOCATION_AUTOCOMPLETE_COUNTRIES' ? 'jo' : undefined,
      );
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.9106, 31.9539] },
              properties: { name: 'عمان', countrycode: 'JO' },
            },
            {
              geometry: { type: 'Point', coordinates: [31.2357, 30.0444] },
              properties: { name: 'القاهرة', countrycode: 'EG' },
            },
          ],
        },
      } as never);

      const service = build();

      const result = await service.autocomplete({ q: 'ا' + 'ل' }, 'user-1');

      expect(result.suggestions).toHaveLength(1);
      expect(result.suggestions[0].primaryText).toBe('عمان');
    });

    it('over-fetches from the provider so local filtering cannot empty the list', async () => {
      (configService.get as jest.Mock).mockImplementation((key: string) =>
        key === 'LOCATION_AUTOCOMPLETE_COUNTRIES' ? 'jo' : undefined,
      );
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      await build().autocomplete({ q: 'عما' }, 'user-1');

      const params = mockedAxios.get.mock.calls[0][1]?.params as {
        limit: number;
      };
      expect(params.limit).toBeGreaterThan(6);
    });

    it('skips the provider for queries shorter than two characters', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      const service = build();

      const result = await service.autocomplete({ q: 'a' }, 'user-1');

      expect(result.suggestions).toEqual([]);
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });

    it('returns a distance for each suggestion when a search context is sent', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              // ~2 km north of the context point.
              geometry: { type: 'Point', coordinates: [35.9106, 31.9719] },
              properties: { name: 'الدوار السابع', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete(
        { q: 'الدوار', lat: '31.9539', lng: '35.9106' },
        'user-1',
      );

      const distance = result.suggestions[0].distanceMeters;
      expect(distance).not.toBeNull();
      expect(distance).toBeGreaterThan(1_800);
      expect(distance).toBeLessThan(2_200);
    });

    it('ignores a half-sent coordinate pair instead of biasing on it', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      await build().autocomplete({ q: 'عما', lat: '31.9539' }, 'user-1');

      const params = mockedAxios.get.mock.calls[0][1]?.params as {
        lat?: number;
        lon?: number;
      };
      expect(params.lat).toBeUndefined();
      expect(params.lon).toBeUndefined();
    });

    it('biases the search on the chosen city when no coordinates are sent', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      await build().autocomplete({ q: 'شارع', cityId: 'jo-irbid' }, 'user-1');

      const params = mockedAxios.get.mock.calls[0][1]?.params as {
        lat?: number;
        lon?: number;
      };
      expect(params.lat).toBeCloseTo(32.5556, 3);
      expect(params.lon).toBeCloseTo(35.85, 3);
    });

    it('ranks results inside the chosen city above distant ones', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              // Aqaba: far from Irbid, but first in the provider's own order.
              geometry: { type: 'Point', coordinates: [35.0063, 29.5321] },
              properties: { name: 'شارع البحر', countrycode: 'JO' },
            },
            {
              geometry: { type: 'Point', coordinates: [35.852, 32.5561] },
              properties: { name: 'شارع الجامعة', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete(
        { q: 'شارع', cityId: 'jo-irbid' },
        'user-1',
      );

      expect(result.suggestions[0].primaryText).toBe('شارع الجامعة');
      expect(result.suggestions[1].primaryText).toBe('شارع البحر');
    });

    it('orders results nearest first when a search context is sent', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.9106, 31.9719] },
              properties: { name: 'الأول', countrycode: 'JO' },
            },
            {
              // Closer to the context, but ranked lower by the provider.
              geometry: { type: 'Point', coordinates: [35.9106, 31.9549] },
              properties: { name: 'الثاني', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete(
        { q: 'شا', lat: '31.9539', lng: '35.9106' },
        'user-1',
      );

      expect(result.suggestions.map((s) => s.primaryText)).toEqual([
        'الثاني',
        'الأول',
      ]);
    });

    it('keeps provider relevance order when no search context is sent', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.9106, 31.9719] },
              properties: { name: 'الأول', countrycode: 'JO' },
            },
            {
              geometry: { type: 'Point', coordinates: [35.9106, 31.9549] },
              properties: { name: 'الثاني', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete({ q: 'شا' }, 'user-1');

      expect(result.suggestions.map((s) => s.primaryText)).toEqual([
        'الأول',
        'الثاني',
      ]);
    });

    it('searches a ta-marbuta variant alongside the text as typed', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      await build().autocomplete({ q: 'الجامعة الاردنية' }, 'user-1');

      const sent = mockedAxios.get.mock.calls.map(
        (call) => (call[1]?.params as { q: string }).q,
      );
      // Raw first: callers rely on that one deciding success.
      expect(sent[0]).toBe('الجامعة الاردنية');
      expect(sent).toContain('الجامعه الاردنيه');
    });

    it('searches a restored-hamza variant for a bare initial alef', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      await build().autocomplete({ q: 'اربد' }, 'user-1');

      const sent = mockedAxios.get.mock.calls.map(
        (call) => (call[1]?.params as { q: string }).q,
      );
      expect(sent).toEqual(['اربد', 'إربد']);
    });

    it('never rewrites the definite article into a non-word', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      await build().autocomplete({ q: 'الجاردنز' }, 'user-1');

      const sent = mockedAxios.get.mock.calls.map(
        (call) => (call[1]?.params as { q: string }).q,
      );
      // "إلجاردنز" is not a word, so no variant is worth a second request.
      expect(sent).toEqual(['الجاردنز']);
    });

    it('lists the same place once when two variants both return it', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      const university = {
        geometry: { type: 'Point', coordinates: [35.8721, 32.0125] },
        properties: {
          name: 'الجامعة الأردنية',
          countrycode: 'JO',
          osm_type: 'W',
          osm_id: 111,
        },
      };
      mockedAxios.get.mockResolvedValue({
        data: { features: [university] },
      } as never);

      const result = await build().autocomplete(
        { q: 'الجامعة الاردنية' },
        'user-1',
      );

      expect(mockedAxios.get).toHaveBeenCalledTimes(2);
      expect(result.suggestions).toHaveLength(1);
    });

    it('still answers when a spelling variant fails but the raw query works', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get
        .mockResolvedValueOnce({
          data: {
            features: [
              {
                geometry: { type: 'Point', coordinates: [35.85, 32.5556] },
                properties: { name: 'إربد', countrycode: 'JO' },
              },
            ],
          },
        } as never)
        .mockRejectedValueOnce(new Error('variant timed out'));

      const result = await build().autocomplete({ q: 'اربد' }, 'user-1');

      expect(result.suggestions[0].primaryText).toBe('إربد');
    });

    it('fails when the raw query fails, even if a variant succeeded', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get
        .mockRejectedValueOnce(new Error('provider down'))
        .mockResolvedValueOnce({ data: { features: [] } } as never);

      await expect(
        build().autocomplete({ q: 'اربد' }, 'user-1'),
      ).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('sinks a bus stop below the place it stands outside', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              // Ranked first by the provider, but not what anyone searched for.
              geometry: { type: 'Point', coordinates: [35.8724, 32.0128] },
              properties: {
                name: 'موقف باص مسجد الجامعة الاردنية',
                countrycode: 'JO',
                osm_type: 'N',
                osm_id: 1,
                osm_key: 'highway',
                osm_value: 'bus_stop',
              },
            },
            {
              geometry: { type: 'Point', coordinates: [35.8721, 32.0125] },
              properties: {
                name: 'الجامعة الأردنية',
                countrycode: 'JO',
                osm_type: 'W',
                osm_id: 2,
                osm_key: 'amenity',
                osm_value: 'university',
              },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete({ q: 'الجامعه' }, 'user-1');

      expect(result.suggestions[0].primaryText).toBe('الجامعة الأردنية');
      // Demoted, not dropped: someone really looking for the stop still finds it.
      expect(result.suggestions[1].primaryText).toBe(
        'موقف باص مسجد الجامعة الاردنية',
      );
    });

    it('lifts a city above nearby noise when the query names it', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              // A shop 4 km from the searcher, which proximity ranking loves.
              geometry: { type: 'Point', coordinates: [35.88, 31.99] },
              properties: { name: 'العوده', countrycode: 'JO' },
            },
            {
              // Aqaba itself, 300 km south.
              geometry: { type: 'Point', coordinates: [35.0063, 29.5321] },
              properties: { name: 'العقبة', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete(
        { q: 'العقبه', lat: '31.9539', lng: '35.9106' },
        'user-1',
      );

      expect(result.suggestions[0].primaryText).toBe('العقبة');
    });

    it('never promotes a same-named place that is nowhere near the city', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              // Named "العقبة" but thousands of km away, so not Aqaba.
              geometry: { type: 'Point', coordinates: [10.0, 36.0] },
              properties: { name: 'العقبة', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete(
        { q: 'العقبه', lat: '31.9539', lng: '35.9106' },
        'user-1',
      );

      const [top] = result.suggestions;
      const detail = await build().placeDetail(top.placeId);
      // The catalog entry was added instead of promoting the impostor.
      expect(detail.lat).toBeCloseTo(29.5321, 2);
      expect(detail.lng).toBeCloseTo(35.0063, 2);
    });

    it('adds the city the app knows when the provider misses it', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.72, 32.05] },
              properties: { name: 'اربد القديم', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete({ q: 'اربد' }, 'user-1');

      expect(result.suggestions[0].primaryText).toBe('إربد');
      // The provider's own result is kept below it, not discarded.
      expect(result.suggestions[1].primaryText).toBe('اربد القديم');
    });

    it('leaves address search alone once a city has been chosen', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.852, 32.5561] },
              properties: { name: 'شارع الجامعة', countrycode: 'JO' },
            },
          ],
        },
      } as never);

      const result = await build().autocomplete(
        // "السلط" names a city, but the user is searching inside Irbid.
        { q: 'السلط', cityId: 'jo-irbid' },
        'user-1',
      );

      expect(result.suggestions[0].primaryText).toBe('شارع الجامعة');
    });

    it('rejects the request when the rate limiter refuses it', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      (rateLimiter.consume as jest.Mock).mockResolvedValue({
        allowed: false,
        retryAfterSeconds: 42,
      });

      await expect(
        build().autocomplete({ q: 'عما' }, 'user-1'),
      ).rejects.toBeInstanceOf(HttpException);
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });

    it('surfaces a provider outage as 502 without leaking the provider error', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockRejectedValue(
        new Error('connect ECONNREFUSED 10.0.0.1:2322'),
      );

      await expect(
        build().autocomplete({ q: 'عما' }, 'user-1'),
      ).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('stops calling a repeatedly failing provider until the breaker cools down', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockRejectedValue(new Error('provider down'));
      const service = build();

      // Distinct queries so the cache cannot mask the calls.
      for (const q of ['aa', 'bb', 'cc', 'dd', 'ee']) {
        await expect(
          service.autocomplete({ q }, 'user-1'),
        ).rejects.toBeInstanceOf(BadGatewayException);
      }
      expect(mockedAxios.get).toHaveBeenCalledTimes(5);

      mockedAxios.get.mockClear();
      await expect(
        service.autocomplete({ q: 'ff' }, 'user-1'),
      ).rejects.toBeInstanceOf(BadGatewayException);
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });
  });

  describe('reverse', () => {
    it('resolves a map point to primary and secondary address lines', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({
        data: {
          features: [
            {
              geometry: { type: 'Point', coordinates: [35.9106, 31.9539] },
              properties: {
                name: 'شارع الرينبو',
                district: 'جبل عمان',
                city: 'عمان',
                countrycode: 'JO',
              },
            },
          ],
        },
      } as never);

      const result = await build().reverse(
        { lat: '31.9539', lng: '35.9106' },
        'user-1',
      );

      expect(result.primaryText).toBe('شارع الرينبو');
      expect(result.secondaryText).toBe('جبل عمان، عمان');
      expect(result.label).toBe('شارع الرينبو، جبل عمان، عمان');
      expect(result.lat).toBeCloseTo(31.9539, 4);
      expect(result.lng).toBeCloseTo(35.9106, 4);
    });

    it('returns the point with empty text when the provider knows no address', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      mockedAxios.get.mockResolvedValue({ data: { features: [] } } as never);

      const result = await build().reverse(
        { lat: '31.0', lng: '35.0' },
        'user-1',
      );

      // The app still lets the user confirm the point, so this is not an error.
      expect(result.label).toBe('');
      expect(result.lat).toBe(31);
    });

    it('rejects out-of-range coordinates before calling the provider', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);

      await expect(
        build().reverse({ lat: '99.5', lng: '35.0' }, 'user-1'),
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

  describe('placeDetail', () => {
    it('rejects an unrecognised placeId', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      const service = build();

      await expect(service.placeDetail('ChIJgoogleId')).rejects.toBeInstanceOf(
        NotFoundException,
      );
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
});
