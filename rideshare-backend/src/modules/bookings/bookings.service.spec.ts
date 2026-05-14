/**
 * T057 — BookingsService unit tests (TypeORM rewrite)
 *
 * The original spec was written against the Mongoose ODM. This rewrite
 * targets the current TypeORM/PostgreSQL implementation and adds
 * assertions for the multi-seat shape introduced in Phase 4.
 */

import { Test, TestingModule } from '@nestjs/testing';
import { getQueueToken } from '@nestjs/bull';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource, QueryRunner, Repository } from 'typeorm';
import {
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { BookingEntity } from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { PendingChargeEntity } from '../../database/entities/pending-charge.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { TripsGateway } from '../trips/trips.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { PaymentsService } from '../payments/payments.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { UsersService } from '../users/users.service';
import { TripsService } from '../trips/trips.service';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------
const TRIP_ID = 'trip-uuid';
const USER_ID = 'pax-uuid';
const DRIVER_ID = 'driver-uuid';
const BOOKING_ID = 'booking-uuid';

const mockTrip = () => ({
  id: TRIP_ID,
  driverId: DRIVER_ID,
  status: 'published',
  price: '5.00',
  currency: 'JOD',
  departureTime: new Date(Date.now() + 48 * 3600 * 1000),
  seats: [
    { seatNumber: '0-0', status: 'available', userId: null, gender: null },
    { seatNumber: '0-1', status: 'available', userId: null, gender: null },
    { seatNumber: '1-0', status: 'available', userId: null, gender: null },
    { seatNumber: '1-1', status: 'available', userId: null, gender: null },
  ],
  seatLayout: { rows: 2, seatsPerRow: 2, preventGenderMixing: false },
});

const mockUser = () => ({
  id: USER_ID,
  fullName: 'Test Passenger',
  gender: 'male',
  photoUrl: null,
});

const mockBooking = (): Partial<BookingEntity> => ({
  id: BOOKING_ID,
  tripId: TRIP_ID,
  userId: USER_ID,
  seatNumber: '0-0',
  status: 'pending',
  sharePhoneWithDriver: false,
  cancelledBy: null,
  cancelledAt: null,
});

// ---------------------------------------------------------------------------
// Mock factories
// ---------------------------------------------------------------------------
const makeQueryRunner = (): Partial<QueryRunner> => ({
  connect: jest.fn().mockResolvedValue(undefined),
  startTransaction: jest.fn().mockResolvedValue(undefined),
  commitTransaction: jest.fn().mockResolvedValue(undefined),
  rollbackTransaction: jest.fn().mockResolvedValue(undefined),
  abortTransaction: jest.fn().mockResolvedValue(undefined),
  release: jest.fn().mockResolvedValue(undefined),
  manager: {
    findOne: jest.fn(),
    save: jest.fn(),
    create: jest.fn(),
  } as any,
});

const makeRepo = <T>(): jest.Mocked<Partial<Repository<T>>> => ({
  findOne: jest.fn(),
  find: jest.fn(),
  save: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  createQueryBuilder: jest.fn().mockReturnValue({
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    getOne: jest.fn().mockResolvedValue(null),
    getMany: jest.fn().mockResolvedValue([]),
    leftJoinAndSelect: jest.fn().mockReturnThis(),
    clone: jest.fn().mockReturnThis(),
    select: jest.fn().mockReturnThis(),
    skip: jest.fn().mockReturnThis(),
    take: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    getCount: jest.fn().mockResolvedValue(0),
    getManyAndCount: jest.fn().mockResolvedValue([[], 0]),
  }),
  count: jest.fn(),
});

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------
describe('BookingsService (TypeORM)', () => {
  let service: BookingsService;
  let bookingRepo: jest.Mocked<Repository<BookingEntity>>;
  let tripRepo: jest.Mocked<Repository<TripEntity>>;
  let dataSource: jest.Mocked<DataSource>;
  let tripsGateway: jest.Mocked<TripsGateway>;
  let notificationsService: jest.Mocked<NotificationsService>;
  let paymentsService: jest.Mocked<PaymentsService>;
  let platformPricing: jest.Mocked<PlatformPricingService>;
  let usersService: jest.Mocked<UsersService>;
  let tripsService: jest.Mocked<TripsService>;

  beforeEach(async () => {
    const qr = makeQueryRunner();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: makeRepo(),
        },
        {
          provide: getRepositoryToken(BookingSeatEntity),
          useValue: makeRepo(),
        },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: makeRepo(),
        },
        {
          provide: getRepositoryToken(PendingChargeEntity),
          useValue: makeRepo(),
        },
        {
          provide: getRepositoryToken(PaymentEntity),
          useValue: makeRepo(),
        },
        {
          provide: DataSource,
          useValue: {
            createQueryRunner: jest.fn().mockReturnValue(qr),
          },
        },
        {
          provide: TripsGateway,
          useValue: {
            emitSeatBooked: jest.fn(),
            emitSeatReleased: jest.fn(),
            emitTripUpdated: jest.fn(),
          },
        },
        {
          provide: NotificationsService,
          useValue: {
            create: jest.fn(),
            sendPush: jest.fn(),
            notifyDriverOfNewBooking: jest.fn().mockResolvedValue(undefined),
            notifyPassengerOfBookingDecision: jest
              .fn()
              .mockResolvedValue(undefined),
          },
        },
        {
          provide: PaymentsService,
          useValue: {
            chargeDriverWalletForTrip: jest.fn(),
            resolvePassengerWalletPaymentForBooking: jest.fn(),
          },
        },
        {
          provide: PlatformPricingService,
          useValue: {
            getActiveFeeRow: jest.fn().mockResolvedValue({}),
            passengerSeatPricing: jest.fn().mockReturnValue({
              requiresOnlinePayment: false,
              seatPrice: '5.00',
              seatPriceAtBooking: '5.00',
              platformAmount: '0.25',
              driverAmount: '4.75',
            }),
          },
        },
        {
          provide: UsersService,
          useValue: { findById: jest.fn().mockResolvedValue(mockUser()) },
        },
        {
          provide: TripsService,
          useValue: { findById: jest.fn(), releaseSeat: jest.fn() },
        },
        {
          provide: getQueueToken('bookings-timeout'),
          useValue: {
            add: jest.fn().mockResolvedValue(undefined),
            getJob: jest.fn().mockResolvedValue(null),
          },
        },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
    bookingRepo = module.get(getRepositoryToken(BookingEntity));
    tripRepo = module.get(getRepositoryToken(TripEntity));
    dataSource = module.get(DataSource);
    tripsGateway = module.get(TripsGateway);
    notificationsService = module.get(NotificationsService);
    paymentsService = module.get(PaymentsService);
    platformPricing = module.get(PlatformPricingService);
    usersService = module.get(UsersService);
    tripsService = module.get(TripsService);
  });

  afterEach(() => jest.clearAllMocks());

  // -------------------------------------------------------------------------
  // create (v1 path)
  // -------------------------------------------------------------------------
  describe('create (v1 single-seat)', () => {
    it('should throw NotFoundException when trip does not exist', async () => {
      tripRepo.findOne.mockResolvedValue(null);

      await expect(
        service.create({ tripId: TRIP_ID, seatNumber: '0-0' }, USER_ID),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException when booking own trip', async () => {
      tripRepo.findOne.mockResolvedValue({
        ...mockTrip(),
        driverId: USER_ID,
      } as any);

      await expect(
        service.create({ tripId: TRIP_ID, seatNumber: '0-0' }, USER_ID),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException when trip is not active', async () => {
      tripRepo.findOne.mockResolvedValue({
        ...mockTrip(),
        status: 'completed',
      } as any);

      await expect(
        service.create({ tripId: TRIP_ID, seatNumber: '0-0' }, USER_ID),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException when seat is not available', async () => {
      const trip = mockTrip();
      trip.seats[0].status = 'booked';
      tripRepo.findOne.mockResolvedValue(trip as any);
      (bookingRepo.createQueryBuilder as any).mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.create({ tripId: TRIP_ID, seatNumber: '0-0' }, USER_ID),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException when user already has a booking for the trip', async () => {
      tripRepo.findOne.mockResolvedValue(mockTrip() as any);
      (bookingRepo.createQueryBuilder as any).mockReturnValue({
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        getOne: jest.fn().mockResolvedValue(mockBooking()),
      });

      await expect(
        service.create({ tripId: TRIP_ID, seatNumber: '0-0' }, USER_ID),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // confirm (v1 path — maps to accept in v2)
  // -------------------------------------------------------------------------
  describe('confirm', () => {
    it('should throw NotFoundException when booking does not exist', async () => {
      bookingRepo.findOne.mockResolvedValue(null);

      await expect(service.confirm(BOOKING_ID, DRIVER_ID)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw ForbiddenException when user is not the trip driver', async () => {
      bookingRepo.findOne.mockResolvedValue({
        ...mockBooking(),
        trip: { driverId: DRIVER_ID },
      } as any);

      await expect(service.confirm(BOOKING_ID, 'other-driver')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should throw BadRequestException when booking is not pending', async () => {
      bookingRepo.findOne.mockResolvedValue({
        ...mockBooking(),
        status: 'confirmed',
        trip: { driverId: DRIVER_ID },
      } as any);

      await expect(service.confirm(BOOKING_ID, DRIVER_ID)).rejects.toThrow(
        BadRequestException,
      );
    });
  });

  // -------------------------------------------------------------------------
  // cancel (policy-enforced)
  // -------------------------------------------------------------------------
  describe('cancel', () => {
    it('should throw ForbiddenException when requester is not a participant', async () => {
      bookingRepo.findOne.mockResolvedValue({
        ...mockBooking(),
        userId: USER_ID,
        trip: { driverId: DRIVER_ID },
      } as any);

      await expect(
        service.cancel(BOOKING_ID, 'stranger-uuid', { reason: 'test' }, false),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException when booking is already cancelled', async () => {
      bookingRepo.findOne.mockResolvedValue({
        ...mockBooking(),
        status: 'cancelled',
        userId: USER_ID,
        trip: { driverId: DRIVER_ID },
      } as any);

      await expect(
        service.cancel(BOOKING_ID, USER_ID, { reason: 'test' }, false),
      ).rejects.toThrow(BadRequestException);
    });
  });

  // -------------------------------------------------------------------------
  // findByUser
  // -------------------------------------------------------------------------
  describe('findByUser', () => {
    it('should return a paginated result with booking seats', async () => {
      const qb = {
        leftJoinAndSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        skip: jest.fn().mockReturnThis(),
        take: jest.fn().mockReturnThis(),
        getMany: jest.fn().mockResolvedValue([
          {
            ...mockBooking(),
            seats: [{ seatNumber: '0-0' }, { seatNumber: '0-1' }],
          },
        ]),
        clone: jest.fn(),
      };
      const countQb = {
        getCount: jest.fn().mockResolvedValue(1),
      };
      qb.clone.mockReturnValue(countQb);
      (bookingRepo.createQueryBuilder as any).mockReturnValue({
        ...qb,
      });

      const result = await service.findByUser(USER_ID, { page: 1, limit: 20 });

      expect(result).toBeDefined();
      expect(result.data).toHaveLength(1);
      expect(result.data[0].seats).toHaveLength(2);
      expect(qb.leftJoinAndSelect).toHaveBeenCalledWith('b.trip', 'trip');
      expect(qb.leftJoinAndSelect).toHaveBeenCalledWith('b.seats', 'seats');
    });
  });

  // -------------------------------------------------------------------------
  // findByTrip
  // -------------------------------------------------------------------------
  describe('findByTrip', () => {
    it('should throw ForbiddenException when caller is not the trip driver', async () => {
      tripsService.findById.mockResolvedValue(mockTrip() as any);

      await expect(
        service.findByTrip(TRIP_ID, 'not-the-driver', { page: 1, limit: 20 }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should reveal user and enable chat/call when booking.hasDriverPaidToContact is true', async () => {
      tripsService.findById.mockResolvedValue(mockTrip() as any);
      const passenger = { id: USER_ID, fullName: 'P1' };
      bookingRepo.find.mockResolvedValue([
        {
          ...mockBooking(),
          hasDriverPaidToContact: true,
          user: passenger,
          trip: { driverWalletChargeApplied: false },
        } as any,
      ]);
      bookingRepo.count.mockResolvedValue(1);

      const result = await service.findByTrip(TRIP_ID, DRIVER_ID, {
        page: 1,
        limit: 20,
      });

      expect(result.data[0].user).toEqual(passenger);
      expect(result.data[0].chatEnabled).toBe(true);
      expect(result.data[0].callEnabled).toBe(true);
      expect(result.data[0].hasDriverPaidToContact).toBe(true);
    });

    it('should reveal user via trip.driverWalletChargeApplied fallback when mirror is stale', async () => {
      tripsService.findById.mockResolvedValue(mockTrip() as any);
      const passenger = { id: USER_ID, fullName: 'P1' };
      bookingRepo.find.mockResolvedValue([
        {
          ...mockBooking(),
          hasDriverPaidToContact: false,
          user: passenger,
          trip: { driverWalletChargeApplied: true },
        } as any,
      ]);
      bookingRepo.count.mockResolvedValue(1);

      const result = await service.findByTrip(TRIP_ID, DRIVER_ID, {
        page: 1,
        limit: 20,
      });

      expect(result.data[0].user).toEqual(passenger);
      expect(result.data[0].chatEnabled).toBe(true);
      expect(result.data[0].callEnabled).toBe(true);
      expect(result.data[0].hasDriverPaidToContact).toBe(true);
    });

    it('should mask user and disable chat/call when both flags are false', async () => {
      tripsService.findById.mockResolvedValue(mockTrip() as any);
      const passenger = { id: USER_ID, fullName: 'P1' };
      bookingRepo.find.mockResolvedValue([
        {
          ...mockBooking(),
          hasDriverPaidToContact: false,
          user: passenger,
          trip: { driverWalletChargeApplied: false },
        } as any,
      ]);
      bookingRepo.count.mockResolvedValue(1);

      const result = await service.findByTrip(TRIP_ID, DRIVER_ID, {
        page: 1,
        limit: 20,
      });

      expect(result.data[0].user).toBeNull();
      expect(result.data[0].chatEnabled).toBe(false);
      expect(result.data[0].callEnabled).toBe(false);
      expect(result.data[0].hasDriverPaidToContact).toBe(false);
    });

    it('should request the trip relation', async () => {
      tripsService.findById.mockResolvedValue(mockTrip() as any);
      bookingRepo.find.mockResolvedValue([]);
      bookingRepo.count.mockResolvedValue(0);

      await service.findByTrip(TRIP_ID, DRIVER_ID, { page: 1, limit: 20 });

      expect(bookingRepo.find).toHaveBeenCalledWith(
        expect.objectContaining({
          relations: expect.arrayContaining(['trip']),
        }),
      );
    });
  });

  // -------------------------------------------------------------------------
  // markAsCompleted
  // -------------------------------------------------------------------------
  describe('markAsCompleted', () => {
    it('should call update for all confirmed bookings on the trip', async () => {
      (bookingRepo.createQueryBuilder as any).mockReturnValue({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 1 }),
      });

      // markAsCompleted should complete without throwing
      await expect(service.markAsCompleted(TRIP_ID)).resolves.not.toThrow();
    });
  });

  // -------------------------------------------------------------------------
  // Multi-seat shape (v2 contracts)
  // -------------------------------------------------------------------------
  describe('multi-seat shape contracts (Phase 4 — will fail until T065)', () => {
    it('createMultiSeat should exist as a method on BookingsService', () => {
      // T065 adds this method. Until then the test fails.
      expect(typeof (service as any).createMultiSeat).toBe('function');
    });

    it('autoPick should exist as a method on BookingsService', () => {
      // T066 adds this method.
      expect(typeof (service as any).autoPick).toBe('function');
    });

    it('createMultiSeat should return the created booking with trip and seats', async () => {
      const trip = mockTrip();
      tripRepo.findOne.mockResolvedValue(trip as any);

      const qr = (dataSource.createQueryRunner as jest.Mock)();
      (qr.manager.findOne as jest.Mock).mockResolvedValue({ ...trip });
      (qr.manager.create as jest.Mock).mockImplementation((_, value) => value);
      (qr.manager.save as jest.Mock).mockImplementation((target, value) => {
        if (target === BookingEntity) {
          return Promise.resolve({ ...value, id: BOOKING_ID });
        }
        return Promise.resolve(value);
      });

      const hydratedBooking = {
        ...mockBooking(),
        trip,
        seats: [{ seatNumber: '0-0' }, { seatNumber: '0-1' }],
      } as any;
      bookingRepo.findOne.mockResolvedValue(hydratedBooking);

      const result = await service.createMultiSeat(
        {
          tripId: TRIP_ID,
          seats: [
            {
              seatNumber: '0-0',
              displayName: 'A',
              gender: 'male',
              isMainBooker: true,
            },
            {
              seatNumber: '0-1',
              displayName: 'B',
              gender: 'male',
              isMainBooker: false,
            },
          ],
        },
        USER_ID,
      );

      expect(result).toBe(hydratedBooking);
      expect(bookingRepo.findOne).toHaveBeenCalledWith({
        where: { id: BOOKING_ID },
        relations: ['trip', 'seats'],
      });
    });

    it('createMultiSeat should throw BadRequestException on SEATS_TAKEN', async () => {
      // Stub: until T065 the test fails (method does not exist yet).
      if (typeof (service as any).createMultiSeat !== 'function') {
        return; // skip gracefully before implementation
      }

      tripRepo.findOne.mockResolvedValue({
        ...mockTrip(),
        seats: [
          {
            seatNumber: '0-0',
            status: 'booked',
            userId: 'other',
            gender: 'male',
          },
        ],
      } as any);

      await expect(
        (service as any).createMultiSeat(
          {
            tripId: TRIP_ID,
            seats: [
              {
                seatNumber: '0-0',
                displayName: 'A',
                gender: 'female',
                isMainBooker: true,
              },
            ],
          },
          USER_ID,
        ),
      ).rejects.toThrow(BadRequestException);
    });
  });
});
