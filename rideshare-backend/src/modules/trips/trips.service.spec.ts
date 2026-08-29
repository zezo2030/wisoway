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
import { NotificationsService } from '../notifications/notifications.service';
import { BookingsService } from '../bookings/bookings.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { UsersService } from '../users/users.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { TripsGateway } from './trips.gateway';
import { RecurrenceService } from '../recurrence/recurrence.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { LocationsService } from '../locations/locations.service';
import { DriverTripFeeService } from '../driver-trip-fee/driver-trip-fee.service';
import { TripPassengerSummaryService } from '../bookings/trip-passenger-summary.service';
import { ErrorCodes } from '../../common/errors/error-codes';

const DRIVER_ID = 'driver-uuid';
const DRIVER_NAME = 'Test Driver';

/** Standard car: 1 front passenger seat + 3 back seats. */
const mockVehicle = () => ({
  id: 'vehicle-uuid',
  driverId: DRIVER_ID,
  vehicleType: 'standard_car',
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
  let driverTripFee: any;
  let locationsService: any;
  let passengerSummary: any;

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
              select: jest.fn().mockReturnThis(),
              where: jest.fn().mockReturnThis(),
              andWhere: jest.fn().mockReturnThis(),
              addSelect: jest.fn().mockReturnThis(),
              orderBy: jest.fn().mockReturnThis(),
              skip: jest.fn().mockReturnThis(),
              take: jest.fn().mockReturnThis(),
              getRawOne: jest.fn().mockResolvedValue(undefined),
              getRawAndEntities: jest
                .fn()
                .mockResolvedValue({ entities: [], raw: [] }),
            }),
          },
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
            getDistance: jest.fn(),
          },
        },
        {
          provide: TripPassengerSummaryService,
          useValue: { forTrips: jest.fn().mockResolvedValue(new Map()) },
        },
        {
          provide: DriverTripFeeService,
          useValue: {
            assertDriverCanCoverTripFee: jest
              .fn()
              .mockResolvedValue({ amount: 1.6 }),
            computeExpectedFee: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<TripsService>(TripsService);
    tripRepo = module.get(getRepositoryToken(TripEntity));
    vehiclesService = module.get(VehiclesService);
    usersService = module.get(UsersService);
    recurrenceService = module.get(RecurrenceService);
    driverTripFee = module.get<DriverTripFeeService>(DriverTripFeeService);
    locationsService = module.get<LocationsService>(LocationsService);
    passengerSummary = module.get<TripPassengerSummaryService>(
      TripPassengerSummaryService,
    );
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

    it('rejects an out-of-range seat count before resolving currency or checking the fee guard', async () => {
      // Pins the order: the seat-count range check is local/pure and must run
      // before the geocode behind resolveTripCurrency and before the fee
      // guard, so an invalid request never pays for either.
      await expect(
        service.create(
          { ...baseDto(), availableSeats: 99 },
          DRIVER_ID,
          DRIVER_NAME,
        ),
      ).rejects.toThrow(BadRequestException);

      expect(locationsService.reverseGeocode).not.toHaveBeenCalled();
      expect(driverTripFee.assertDriverCanCoverTripFee).not.toHaveBeenCalled();
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
          {
            ...baseDto(),
            departureTime: new Date(Date.now() - 1000).toISOString(),
          },
          DRIVER_ID,
          DRIVER_NAME,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects an invalid departure time before resolving currency or checking the fee guard', async () => {
      // Pins the order: outstanding-charges -> departure-time -> seat-count ->
      // resolveTripCurrency -> fee-guard. A driver who submits both a past
      // departure time and an unaffordable trip must see the departure-time
      // error, and the request must never pay for the geocode or wallet read
      // behind the later checks.
      driverTripFee.assertDriverCanCoverTripFee.mockRejectedValue(
        new ForbiddenException({
          code: ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE,
        }),
      );

      await expect(
        service.create(
          {
            ...baseDto(),
            departureTime: new Date(Date.now() - 1000).toISOString(),
          },
          DRIVER_ID,
          DRIVER_NAME,
        ),
      ).rejects.toThrow(BadRequestException);

      expect(locationsService.reverseGeocode).not.toHaveBeenCalled();
      expect(driverTripFee.assertDriverCanCoverTripFee).not.toHaveBeenCalled();
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

    it('rejects publishing when the driver cannot cover the trip fee', async () => {
      driverTripFee.assertDriverCanCoverTripFee.mockRejectedValue(
        new ForbiddenException({
          code: ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE,
        }),
      );

      await expect(
        service.create(baseDto(), DRIVER_ID, DRIVER_NAME),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('passes the seat price and total seat count to the fee guard', async () => {
      await service.create({ ...baseDto(), price: 4 }, DRIVER_ID, DRIVER_NAME);

      expect(driverTripFee.assertDriverCanCoverTripFee).toHaveBeenCalledWith(
        DRIVER_ID,
        expect.objectContaining({ seatPrice: 4, totalSeats: 4 }),
      );
    });

    it('passes the resolved trip currency to the fee guard, not the raw DTO value', async () => {
      // The departure point geocodes to Jordan (mocked below), which resolves
      // to JOD — deliberately different from the client-supplied 'USD' so this
      // test fails if the guard were fed the raw DTO currency instead.
      await service.create(
        { ...baseDto(), currency: 'USD' },
        DRIVER_ID,
        DRIVER_NAME,
      );

      expect(driverTripFee.assertDriverCanCoverTripFee).toHaveBeenCalledWith(
        DRIVER_ID,
        expect.objectContaining({ currency: 'JOD' }),
      );
    });
  });

  describe('update', () => {
    /** findById() goes through the query builder, not findOne(). */
    function arrangeTrip(overrides: Partial<TripEntity> = {}) {
      const trip = {
        id: 'trip-uuid',
        driverId: DRIVER_ID,
        price: '1.00',
        currency: 'JOD',
        totalSeats: 4,
        seats: [],
        departureTime: new Date(Date.now() + 48 * 60 * 60 * 1000),
        driverWalletChargeApplied: false,
        ...overrides,
      } as unknown as TripEntity;
      tripRepo.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        addSelect: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getRawAndEntities: jest
          .fn()
          .mockResolvedValue({ entities: [trip], raw: [{}] }),
      });
      return trip;
    }

    it('re-runs the fee guard when the price is raised on an unbilled trip', async () => {
      arrangeTrip();

      await service.update('trip-uuid', { price: 20 } as any, DRIVER_ID);

      expect(driverTripFee.assertDriverCanCoverTripFee).toHaveBeenCalledWith(
        DRIVER_ID,
        expect.objectContaining({ seatPrice: 20, totalSeats: 4 }),
      );
    });

    it('rejects a price rise the driver cannot cover', async () => {
      arrangeTrip();
      driverTripFee.assertDriverCanCoverTripFee.mockRejectedValue(
        new ForbiddenException({
          code: ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE,
        }),
      );

      await expect(
        service.update('trip-uuid', { price: 20 } as any, DRIVER_ID),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(tripRepo.save).not.toHaveBeenCalled();
    });

    it('leaves the guard alone when the price is untouched', async () => {
      arrangeTrip();

      await service.update('trip-uuid', { notes: 'hi' } as any, DRIVER_ID);

      expect(driverTripFee.assertDriverCanCoverTripFee).not.toHaveBeenCalled();
    });

    it('does not re-guard a trip whose fee was already charged', async () => {
      arrangeTrip({ driverWalletChargeApplied: true });

      await service.update('trip-uuid', { price: 20 } as any, DRIVER_ID);

      expect(driverTripFee.assertDriverCanCoverTripFee).not.toHaveBeenCalled();
    });
  });

  describe('findById', () => {
    it('throws NotFoundException when the trip does not exist', async () => {
      await expect(service.findById('missing-uuid')).rejects.toThrow(
        NotFoundException,
      );
    });

    /** Passenger clients pick the cabin artwork by vehicle type, and two types
     * can share a seat layout, so the type has to travel with the trip. */
    it('surfaces the driver vehicle type alongside the other vehicle fields', async () => {
      tripRepo.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        addSelect: jest.fn().mockReturnThis(),
        getRawAndEntities: jest.fn().mockResolvedValue({
          entities: [{ id: 'trip-uuid', driverId: DRIVER_ID }],
          raw: [{}],
        }),
      });
      vehiclesService.findByDriver.mockResolvedValue({
        ...mockVehicle(),
        vehicleType: 'large_bus',
      });

      const trip = await service.findById('trip-uuid');

      expect(trip.vehicleType).toBe('large_bus');
    });

    it('reports a null vehicle type when the driver has no vehicle', async () => {
      tripRepo.createQueryBuilder.mockReturnValue({
        where: jest.fn().mockReturnThis(),
        addSelect: jest.fn().mockReturnThis(),
        getRawAndEntities: jest.fn().mockResolvedValue({
          entities: [{ id: 'trip-uuid', driverId: DRIVER_ID }],
          raw: [{}],
        }),
      });
      vehiclesService.findByDriver.mockResolvedValue(null);

      const trip = await service.findById('trip-uuid');

      expect(trip.vehicleType).toBeNull();
    });
  });

  describe('getPriceSuggestion', () => {
    const route = {
      fromLat: 31.9539,
      fromLng: 35.9106,
      toLat: 32.5556,
      toLng: 35.85,
    };

    /** Point the repo's query builder at one `percentile_cont` result row. */
    const stubSample = (row: any) => {
      const qb = tripRepo.createQueryBuilder();
      qb.getRawOne.mockResolvedValue(row);
      return qb;
    };

    it('suggests the p25-p75 band of comparable past trips', async () => {
      stubSample({ sampleSize: 12, p25: '14.2', p75: '17.8' });

      const suggestion = await service.getPriceSuggestion(route);

      expect(suggestion.basis).toBe('history');
      expect(suggestion.min).toBe(14);
      expect(suggestion.max).toBe(18);
      expect(locationsService.getDistance).not.toHaveBeenCalled();
    });

    it('resolves the currency from the departure point country', async () => {
      stubSample({ sampleSize: 12, p25: '14.2', p75: '17.8' });
      locationsService.reverseGeocode.mockResolvedValue({ countryCode: 'AE' });

      const suggestion = await service.getPriceSuggestion(route);

      expect(suggestion.currency).toBe('AED');
      expect(locationsService.reverseGeocode).toHaveBeenCalledWith(
        route.fromLat,
        route.fromLng,
      );
    });

    it('falls back to the platform default currency when geocoding fails', async () => {
      stubSample({ sampleSize: 12, p25: '14.2', p75: '17.8' });
      locationsService.reverseGeocode.mockRejectedValue(new Error('offline'));

      const suggestion = await service.getPriceSuggestion(route);

      expect(suggestion.currency).toBe('JOD');
    });

    it('widens the band when the historical quartiles collapse', async () => {
      stubSample({ sampleSize: 9, p25: '15', p75: '15' });

      const suggestion = await service.getPriceSuggestion(route);

      expect(suggestion.basis).toBe('history');
      expect(suggestion.max).toBeGreaterThan(suggestion.min);
    });

    it('falls back to a distance band when too few comparable trips exist', async () => {
      stubSample({ sampleSize: 2, p25: '14.2', p75: '17.8' });
      locationsService.getDistance.mockResolvedValue({
        distanceKm: 80,
        durationMinutes: 70,
      });

      const suggestion = await service.getPriceSuggestion(route);

      // 0.5 + 80 * 0.18 = 14.9, +/- 15% -> 12.665 .. 17.135
      expect(suggestion.basis).toBe('distance');
      expect(suggestion.min).toBe(13);
      expect(suggestion.max).toBe(17);
    });

    it('falls back to straight-line distance when the distance service fails', async () => {
      stubSample({ sampleSize: 0, p25: null, p75: null });
      locationsService.getDistance.mockRejectedValue(new Error('no quota'));

      const suggestion = await service.getPriceSuggestion(route);

      expect(suggestion.basis).toBe('distance');
      // Amman -> Irbid is ~70km as the crow flies, so the band stays sane.
      expect(suggestion.min).toBeGreaterThan(1);
      expect(suggestion.max).toBeGreaterThan(suggestion.min);
    });

    it('never suggests below the seat-price minimum', async () => {
      stubSample({ sampleSize: 0, p25: null, p75: null });
      locationsService.getDistance.mockResolvedValue({
        distanceKm: 0.2,
        durationMinutes: 1,
      });

      const suggestion = await service.getPriceSuggestion(route);

      expect(suggestion.min).toBeGreaterThanOrEqual(1);
      expect(suggestion.max).toBeGreaterThan(suggestion.min);
    });
  });

  describe('trip list passenger summary', () => {
    const AMMAN = { latitude: 31.9539, longitude: 35.9106 };

    const listedTrip = (id: string, overrides: any = {}) => ({
      id,
      fromName: 'Amman',
      toName: 'Irbid',
      fromPoint: { type: 'Point', coordinates: [35.9106, 31.9539] },
      toPoint: { type: 'Point', coordinates: [35.85, 32.5556] },
      availableSeats: 3,
      departureTime: new Date(Date.now() + 3600 * 1000),
      ...overrides,
    });

    it.each(['getNearbyTrips', 'getPreferredTrips'] as const)(
      '%s returns each trip with its booked seats and passenger avatars',
      async (method) => {
        tripRepo.find.mockResolvedValue([listedTrip('trip-1')]);
        passengerSummary.forTrips.mockResolvedValue(
          new Map([
            ['trip-1', { bookedSeats: 2, passengerAvatars: ['a.jpg'] }],
          ]),
        );

        const result = await service[method](AMMAN as any);

        expect(result.data[0]).toMatchObject({
          id: 'trip-1',
          bookedSeats: 2,
          passengerAvatars: ['a.jpg'],
        });
      },
    );

    it.each(['getNearbyTrips', 'getPreferredTrips'] as const)(
      '%s reports zero booked seats for a trip nobody booked',
      async (method) => {
        tripRepo.find.mockResolvedValue([listedTrip('trip-1')]);
        passengerSummary.forTrips.mockResolvedValue(new Map());

        const result = await service[method](AMMAN as any);

        expect(result.data[0]).toMatchObject({
          bookedSeats: 0,
          passengerAvatars: [],
        });
      },
    );

    it('summarises only the trips on the returned page, not every candidate', async () => {
      tripRepo.find.mockResolvedValue([
        listedTrip('trip-1'),
        listedTrip('trip-2'),
        listedTrip('trip-full', { availableSeats: 0 }),
        listedTrip('trip-past', {
          departureTime: new Date(Date.now() - 3600 * 1000),
        }),
      ]);
      passengerSummary.forTrips.mockResolvedValue(new Map());

      await service.getNearbyTrips({ ...AMMAN, page: 1, limit: 1 } as any);

      expect(passengerSummary.forTrips).toHaveBeenCalledWith(['trip-1']);
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
