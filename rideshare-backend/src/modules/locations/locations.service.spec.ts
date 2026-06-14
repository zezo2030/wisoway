import { BadRequestException } from '@nestjs/common';
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
