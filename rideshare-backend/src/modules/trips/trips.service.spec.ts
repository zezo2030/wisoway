/**
 * TripsService unit tests (TypeORM rewrite).
 *
 * The original spec targeted the Mongoose ODM and no longer compiled against
 * the current TypeORM implementation. This rewrite focuses on `create`, which
 * owns seat-layout resolution and the per-trip `availableSeats` /
 * `preventGenderMixing` overrides.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bull';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { TripEntity } from '../../database/entities/trip.entity';
import { DriverAvailabilityEntity } from '../../database/entities/driver-availability.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { TripsGateway } from './trips.gateway';
import { RecurrenceService } from '../recurrence/recurrence.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { LocationsService } from '../locations/locations.service';
import { WalletService } from '../wallet/wallet.service';

const DRIVER_ID = 'driver-uuid';
const DRIVER_NAME = 'Test Driver';

/** Sedan-shaped vehicle: 1 front passenger seat + 3 back seats. */
const mockVehicle = () => ({
  id: 'vehicle-uuid',
  driverId: DRIVER_ID,
  vehicleType: 'sedan',
  seats: 4,
  isVerified: true,
  carImageUrl: 'https://cdn.example.com/car.jpg',
  seatLayout: {
    rows: 2,
    seatsPerRow: 3,
    seatsPerRowList: [1, 3],
    preventGenderMixing: true,
  },
});

const baseDto = (): CreateTripDto =>
  ({
    from: {
      name: 'Amman',
      latitude: 31.9539,
      longitude: 35.9106,
      address: 'Amman, Jordan',
    },
    to: {
      name: 'Irbid',
      latitude: 32.5556,
      longitude: 35.85,
      address: 'Irbid, Jordan',
    },
    departureTime: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
    price: 5,
  }) as CreateTripDto;

const makeQueue = () => ({
  add: jest.fn().mockResolvedValue(undefined),
  getJob: jest.fn().mockResolvedValue(null),
});

describe('TripsService (TypeORM)', () => {
  let service: TripsService;
  let tripRepo: any;
  let vehiclesService: any;
  let usersService: any;
  let recurrenceService: any;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripsService,
        {
          provide: getRepositoryToken(TripEntity),
          useValue: {
            create: jest.fn((data: any) => ({ id: 'trip-uuid', ...data })),
            save: jest.fn((entity: any) => Promise.resolve(entity)),
            findOne: jest.fn(),
            find: jest.fn(),
            createQueryBuilder: jest.fn().mockReturnValue({
              where: jest.fn().mockReturnThis(),
              andWhere: jest.fn().mockReturnThis(),
              addSelect: jest.fn().mockReturnThis(),
              orderBy: jest.fn().mockReturnThis(),
              skip: jest.fn().mockReturnThis(),
              take: jest.fn().mockReturnThis(),
              getRawAndEntities: jest
                .fn()
                .mockResolvedValue({ entities: [], raw: [] }),
            }),
          },
        },
        {
          provide: getRepositoryToken(DriverAvailabilityEntity),
          useValue: { findOne: jest.fn(), save: jest.fn() },
        },
        {
          provide: NotificationsService,
          useValue: {
            enqueueCityFanout: jest.fn().mockResolvedValue(undefined),
          },
        },
        { provide: BookingsService, useValue: {} },
        {
          provide: VehiclesService,
          useValue: {
            findByDriver: jest.fn().mockResolvedValue(mockVehicle()),
          },
        },
        {
          provide: UsersService,
          useValue: {
            findById: jest.fn().mockResolvedValue({
              id: DRIVER_ID,
              isDriverApproved: true,
              photoUrl: 'https://cdn.example.com/driver.jpg',
            }),
          },
        },
        { provide: PlatformPricingService, useValue: {} },
        {
          provide: TripsGateway,
          useValue: { emitTripUpdated: jest.fn() },
        },
        { provide: getQueueToken('no-show-detector'), useValue: makeQueue() },
        { provide: getQueueToken('trip-auto-start'), useValue: makeQueue() },
        { provide: getQueueToken('trip-auto-complete'), useValue: makeQueue() },
        {
          provide: RecurrenceService,
          useValue: {
            createRule: jest.fn().mockResolvedValue({ id: 'rule-uuid' }),
          },
        },
        {
          provide: PendingChargesService,
          useValue: {
            getOutstandingSummary: jest
              .fn()
              .mockResolvedValue({ count: 0, totalAmount: 0 }),
          },
        },
        {
          provide: LocationsService,
          useValue: {
            reverseGeocode: jest.fn().mockResolvedValue({ countryCode: 'JO' }),
          },
        },
        {
          provide: WalletService,
          useValue: {
            assertNonNegativeDriverBalance: jest
              .fn()
              .mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    service = module.get<TripsService>(TripsService);
    tripRepo = module.get(getRepositoryToken(TripEntity));
    vehiclesService = module.get(VehiclesService);
    usersService = module.get(UsersService);
    recurrenceService = module.get(RecurrenceService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('create', () => {
    it('publishes every layout seat when no override is supplied', async () => {
      const trip = await service.create(baseDto(), DRIVER_ID, DRIVER_NAME);

      expect(trip.seats).toHaveLength(4);
      expect(trip.totalSeats).toBe(4);
      expect(trip.availableSeats).toBe(4);
      expect(trip.seats.map((s: any) => s.seatNumber)).toEqual([
        '0-0',
        '1-0',
        '1-1',
        '1-2',
      ]);
    });

    it('clamps published seats to the availableSeats override', async () => {
      const trip = await service.create(
        { ...baseDto(), availableSeats: 2 },
        DRIVER_ID,
        DRIVER_NAME,
      );

      expect(trip.totalSeats).toBe(2);
      expect(trip.availableSeats).toBe(2);
      expect(trip.seats).toHaveLength(2);
      expect(trip.seats.map((s: any) => s.seatNumber)).toEqual(['0-0', '1-0']);
    });

    it('overrides preventGenderMixing without mutating the vehicle shape', async () => {
      const vehicle = mockVehicle();
      vehiclesService.findByDriver.mockResolvedValue(vehicle);

      const trip = await service.create(
        { ...baseDto(), preventGenderMixing: false },
        DRIVER_ID,
        DRIVER_NAME,
      );

      expect(trip.seatLayout.preventGenderMixing).toBe(false);
      expect(trip.seatLayout.seatsPerRowList).toEqual([1, 3]);
      expect(vehicle.seatLayout.preventGenderMixing).toBe(true);
      expect(vehicle.seatLayout.seatsPerRowList).toEqual([1, 3]);
    });

    it('inherits the vehicle preventGenderMixing when not overridden', async () => {
      const trip = await service.create(baseDto(), DRIVER_ID, DRIVER_NAME);

      expect(trip.seatLayout.preventGenderMixing).toBe(true);
    });

    it('rejects an availableSeats override above the layout maximum', async () => {
      await expect(
        service.create(
          { ...baseDto(), availableSeats: 99 },
          DRIVER_ID,
          DRIVER_NAME,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects an availableSeats override below one', async () => {
      await expect(
        service.create(
          { ...baseDto(), availableSeats: 0 },
          DRIVER_ID,
          DRIVER_NAME,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('carries the overridden seat count and layout into the recurrence template', async () => {
      await service.create(
        {
          ...baseDto(),
          availableSeats: 3,
          preventGenderMixing: false,
          recurrence: { frequency: 'daily' },
        },
        DRIVER_ID,
        DRIVER_NAME,
      );

      expect(recurrenceService.createRule).toHaveBeenCalled();
      const templateJson = recurrenceService.createRule.mock.calls[0][1];
      expect(templateJson.totalSeats).toBe(3);
      expect(templateJson.seatLayout.preventGenderMixing).toBe(false);
      expect(templateJson.seatLayout.seatsPerRowList).toEqual([1, 3]);
    });

    it('links the saved trip to the created recurrence rule', async () => {
      const trip = await service.create(
        { ...baseDto(), recurrence: { frequency: 'daily' } },
        DRIVER_ID,
        DRIVER_NAME,
      );

      expect(trip.recurrenceRuleId).toBe('rule-uuid');
      expect(tripRepo.save).toHaveBeenCalledTimes(2);
    });

    it('falls back to the vehicle-type template when the vehicle has no layout', async () => {
      vehiclesService.findByDriver.mockResolvedValue({
        ...mockVehicle(),
        seatLayout: null,
      });

      const trip = await service.create(baseDto(), DRIVER_ID, DRIVER_NAME);

      expect(trip.totalSeats).toBe(4);
      expect(trip.seatLayout.seatsPerRowList).toEqual([1, 3]);
      expect(trip.seatLayout.preventGenderMixing).toBe(false);
    });

    it('rejects a departure time in the past', async () => {
      await expect(
        service.create(
          { ...baseDto(), departureTime: new Date(Date.now() - 1000).toISOString() },
          DRIVER_ID,
          DRIVER_NAME,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects a driver without a registered vehicle', async () => {
      vehiclesService.findByDriver.mockResolvedValue(null);

      await expect(
        service.create(baseDto(), DRIVER_ID, DRIVER_NAME),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a driver whose vehicle is not verified', async () => {
      vehiclesService.findByDriver.mockResolvedValue({
        ...mockVehicle(),
        isVerified: false,
      });

      await expect(
        service.create(baseDto(), DRIVER_ID, DRIVER_NAME),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects a driver without a profile photo', async () => {
      usersService.findById.mockResolvedValue({
        id: DRIVER_ID,
        isDriverApproved: true,
        photoUrl: null,
      });

      await expect(
        service.create(baseDto(), DRIVER_ID, DRIVER_NAME),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('findById', () => {
    it('throws NotFoundException when the trip does not exist', async () => {
      await expect(service.findById('missing-uuid')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('generateSeatsGrid', () => {
    it('generates a row-major seat grid', () => {
      const seats = service['generateSeatsGrid'](2, 2);

      expect(seats).toHaveLength(4);
      expect(seats[0].seatNumber).toBe('0-0');
      expect(seats[0].status).toBe('available');
      expect(seats[3].seatNumber).toBe('1-1');
    });
  });
});
