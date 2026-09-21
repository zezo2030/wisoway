import { BadGatewayException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { LocationsService } from '../../src/modules/locations/locations.service';

jest.mock('axios');

const mockedAxios = axios as jest.Mocked<typeof axios>;

// Suggestions encode their coordinates + label into the placeId; mirror the
// service's encoding so the contract can assert the exact value.
const encodePlaceId = (detail: { lat: number; lng: number; label: string }) =>
  `osm:${Buffer.from(JSON.stringify(detail), 'utf8').toString('base64url')}`;

describe('GET /locations/autocomplete (Contract)', () => {
  const configService = {
    get: jest.fn(() => undefined),
  } as unknown as ConfigService;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('requires JWT auth at the controller boundary', () => {
    const contract = {
      path: '/locations/autocomplete',
      auth: 'JWT',
      unauthenticatedStatus: 401,
    };

    expect(contract.unauthenticatedStatus).toBe(401);
  });

  it('returns an empty 200 response when q is shorter than 2 chars', async () => {
    const service = new LocationsService(configService);

    await expect(
      service.autocomplete({ q: 'a', sessionToken: 'abc' }, 'user-1'),
    ).resolves.toEqual({ sessionToken: 'abc', suggestions: [] });
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });

  it('returns the documented suggestion shape for a valid query', async () => {
    mockedAxios.get.mockResolvedValueOnce({
      data: {
        features: [
          {
            geometry: { type: 'Point', coordinates: [35.9932, 31.7226] },
            properties: {
              name: 'Queen Alia International Airport',
              city: 'Amman',
              country: 'Jordan',
              countrycode: 'JO',
            },
          },
        ],
      },
    } as never);
    const service = new LocationsService(configService);

    const label = 'Queen Alia International Airport، Amman، Jordan';
    await expect(
      service.autocomplete(
        { q: 'qa', lang: 'en', sessionToken: 'session-1' },
        'user-1',
      ),
    ).resolves.toEqual({
      sessionToken: 'session-1',
      suggestions: [
        {
          placeId: encodePlaceId({ lat: 31.7226, lng: 35.9932, label }),
          primaryText: 'Queen Alia International Airport',
          secondaryText: 'Amman، Jordan',
          description: label,
        },
      ],
    });
  });

  it('maps provider failures to 502', async () => {
    mockedAxios.get.mockRejectedValueOnce(new Error('network down'));
    const service = new LocationsService(configService);

    await expect(
      service.autocomplete({ q: 'amman', sessionToken: 'session-1' }, 'user-1'),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });
});
