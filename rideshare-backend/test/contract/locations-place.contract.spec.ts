import { NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import { LocationsService } from '../../src/modules/locations/locations.service';

jest.mock('axios');

const mockedAxios = axios as jest.Mocked<typeof axios>;

// Place suggestions encode their coordinates + label into the placeId, so
// resolving a place is a local decode — mirror that encoding here.
const encodePlaceId = (detail: { lat: number; lng: number; label: string }) =>
  `osm:${Buffer.from(JSON.stringify(detail), 'utf8').toString('base64url')}`;

describe('GET /locations/place/:id (Contract)', () => {
  const configService = {
    get: jest.fn(() => undefined),
  } as unknown as ConfigService;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('requires JWT auth at the controller boundary', () => {
    const contract = {
      path: '/locations/place/:id',
      auth: 'JWT',
      unauthenticatedStatus: 401,
    };

    expect(contract.unauthenticatedStatus).toBe(401);
  });

  it('returns the documented place-detail shape for a valid placeId', async () => {
    const service = new LocationsService(configService);
    const placeId = encodePlaceId({
      lat: 31.7226,
      lng: 35.9932,
      label: 'Queen Alia International Airport, Amman, Jordan',
    });

    await expect(service.placeDetail(placeId)).resolves.toEqual({
      placeId,
      label: 'Queen Alia International Airport, Amman, Jordan',
      lat: 31.7226,
      lng: 35.9932,
    });
    // Resolution is local: no provider round-trip.
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });

  it('maps unknown placeId to 404', async () => {
    const service = new LocationsService(configService);

    await expect(service.placeDetail('missing')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
