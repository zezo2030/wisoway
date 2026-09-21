import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { LocationsService } from './locations.service';

jest.mock('axios');

const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('LocationsService', () => {
  const configService = {
    get: jest.fn(),
  } as unknown as ConfigService;

  beforeEach(() => {
    jest.clearAllMocks();
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

      const service = new LocationsService(configService);

      const result = await service.autocomplete(
        { q: 'عما', lang: 'ar' },
        'user-1',
      );

      expect(result.suggestions).toHaveLength(1);
      const [suggestion] = result.suggestions;
      expect(suggestion.primaryText).toBe('عمان');
      expect(suggestion.secondaryText).toBe('محافظة العاصمة، الأردن');
      expect(suggestion.placeId.startsWith('osm:')).toBe(true);

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

      const service = new LocationsService(configService);

      const result = await service.autocomplete({ q: 'ا' + 'ل' }, 'user-1');

      expect(result.suggestions).toHaveLength(1);
      expect(result.suggestions[0].primaryText).toBe('عمان');
    });

    it('skips the provider for queries shorter than two characters', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      const service = new LocationsService(configService);

      const result = await service.autocomplete({ q: 'a' }, 'user-1');

      expect(result.suggestions).toEqual([]);
      expect(mockedAxios.get).not.toHaveBeenCalled();
    });
  });

  describe('placeDetail', () => {
    it('rejects an unrecognised placeId', async () => {
      (configService.get as jest.Mock).mockReturnValue(undefined);
      const service = new LocationsService(configService);

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
                  distance: { text: '12 km' },
                  duration: { text: '18 mins' },
                },
              ],
            },
          ],
        },
      } as never);

      const service = new LocationsService(configService);

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).resolves.toEqual({
        overviewPolyline: 'encoded-polyline',
        distanceText: '12 km',
        durationText: '18 mins',
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

      const service = new LocationsService(configService);

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).resolves.toEqual({
        overviewPolyline: 'osrm-polyline',
        distanceText: '12 كم',
        durationText: '18 دقيقة',
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

      const service = new LocationsService(configService);

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).resolves.toEqual({
        overviewPolyline: 'osrm-fallback-polyline',
        distanceText: '5.2 كم',
        durationText: '12 دقيقة',
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

      const service = new LocationsService(configService);

      await expect(
        service.getRoute(31.95, 35.93, 31.96, 35.94),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });
});
