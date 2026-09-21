import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DriverLocationEntity, TripEntity } from '../../database/entities';
import { TrackingService } from './tracking.service';
import { LocationsService } from '../locations/locations.service';

describe('TrackingService', () => {
  let service: TrackingService;
  let locationRepo: jest.Mocked<Repository<DriverLocationEntity>>;
  let tripRepo: jest.Mocked<Repository<TripEntity>>;
  let locationsService: { getRoute: jest.Mock };

  beforeEach(async () => {
    locationsService = {
      getRoute: jest.fn().mockResolvedValue({
        overviewPolyline: 'abc',
        distanceText: '10 كم',
        durationText: '15 دقيقة',
        distanceMeters: 10000,
        durationSeconds: 900,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TrackingService,
        {
          provide: getRepositoryToken(DriverLocationEntity),
          useValue: {
            create: jest.fn(),
            save: jest.fn(),
            findOne: jest.fn(),
            find: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: {
            findOne: jest.fn(),
            update: jest.fn(),
            createQueryBuilder: jest.fn(),
          },
        },
        {
          provide: LocationsService,
          useValue: locationsService,
        },
      ],
    }).compile();

    service = module.get(TrackingService);
    locationRepo = module.get(getRepositoryToken(DriverLocationEntity));
    tripRepo = module.get(getRepositoryToken(TripEntity));
  });

  it('updates driver location for a valid trip', async () => {
    tripRepo.findOne.mockResolvedValue({
      id: 't1',
      driverId: 'd1',
      toPoint: { type: 'Point', coordinates: [35.9, 31.9] },
      fromPoint: { type: 'Point', coordinates: [35.0, 31.0] },
      etaComputedAt: null,
      remainingDistanceKm: null,
      remainingDurationSeconds: null,
      etaAt: null,
      routeProgressPercent: null,
    } as any);
    locationRepo.create.mockReturnValue({
      id: 'l1',
      tripId: 't1',
      driverId: 'd1',
      point: { type: 'Point', coordinates: [31.2, 30.1] },
      speedKph: '45',
      heading: '120',
      accuracyMeters: '5',
      recordedAt: new Date(),
    } as any);
    locationRepo.save.mockImplementation(async (entity: any) => entity);
    tripRepo.update.mockResolvedValue({ affected: 1 } as any);

    const result = await service.updateDriverLocation('d1', {
      tripId: 't1',
      latitude: 30.1,
      longitude: 31.2,
      speedKph: 45,
      heading: 120,
      accuracyMeters: 5,
    });

    expect(result.tripId).toBe('t1');
    expect(result.driverId).toBe('d1');
    expect(result.latitude).toBe(30.1);
    expect(result.longitude).toBe(31.2);
    expect(result.remainingDistanceKm).toBe(10);
    expect(result.remainingDurationSeconds).toBe(900);
    expect(locationsService.getRoute).toHaveBeenCalled();
  });
});
