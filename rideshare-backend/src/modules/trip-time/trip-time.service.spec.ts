import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { getQueueToken } from '@nestjs/bull';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { NotificationsService } from '../notifications/notifications.service';
import { PresenceService } from './presence.service';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { DriverTripFeeService } from '../driver-trip-fee/driver-trip-fee.service';
import { RidePaymentsService } from '../ride-payments/ride-payments.service';
import { TripTimeService } from './trip-time.service';

describe('TripTimeService.completeTrip — fee reconciliation sweep', () => {
  let service: TripTimeService;
  let trip: any;
  let driverTripFee: { chargeAtTripStart: jest.Mock };
  let presenceService: { settleTripPresence: jest.Mock };
  /** Mutable booking store, so status flips are observable in call order. */
  let bookings: any[];

  beforeEach(async () => {
    bookings = [];
    trip = {
      id: 'trip-1',
      driverId: 'driver-1',
      status: TripStatus.IN_PROGRESS,
      departureTime: new Date(),
      toName: 'الطفيلة',
      price: 4,
      totalSeats: 4,
      driverWalletChargeApplied: false,
    };
    driverTripFee = {
      chargeAtTripStart: jest.fn().mockResolvedValue({
        tripId: 'trip-1',
        charged: 1.6,
        pendingRemainder: 0,
        currency: 'JOD',
        applied: true,
      }),
    };
    presenceService = {
      settleTripPresence: jest.fn().mockResolvedValue({
        tripId: 'trip-1',
        billableSeats: 2,
        bookedSeats: 2,
        captured: 0,
        released: 0,
        currency: 'JOD',
        applied: false,
      }),
    };

    const shareLinkQueryBuilder = {
      update: jest.fn().mockReturnThis(),
      set: jest.fn().mockReturnThis(),
      where: jest.fn().mockReturnThis(),
      execute: jest.fn().mockResolvedValue(undefined),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripTimeService,
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: {
            find: async ({ where }: any) =>
              bookings.filter(
                (b) =>
                  b.tripId === where.tripId &&
                  (where.status === undefined || b.status === where.status),
              ),
            findOne: async ({ where }: any) =>
              bookings.find((b) => b.id === where.id) ?? null,
            // find() hands back live references, so completeTrip's status
            // writes land in `bookings` without save() doing anything.
            save: async (b: any) => b,
          },
        },
        {
          provide: getRepositoryToken(BookingSeatEntity),
          useValue: { find: async () => [], save: async (s: any) => s },
        },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: { findOne: async () => trip, save: async (t: any) => t },
        },
        {
          provide: getRepositoryToken(TripShareLinkEntity),
          useValue: {
            createQueryBuilder: jest.fn(() => shareLinkQueryBuilder),
          },
        },
        {
          provide: getRepositoryToken(UserEntity),
          useValue: {},
        },
        {
          provide: NotificationsService,
          useValue: {
            create: jest.fn().mockResolvedValue({}),
            getPreferredLocale: jest.fn().mockResolvedValue('ar'),
          },
        },
        { provide: PresenceService, useValue: presenceService },
        {
          provide: AdminAlertsService,
          useValue: {},
        },
        {
          provide: getQueueToken('trip-auto-start'),
          useValue: { getJob: jest.fn().mockResolvedValue(undefined) },
        },
        {
          provide: getQueueToken('trip-auto-complete'),
          useValue: { getJob: jest.fn().mockResolvedValue(undefined) },
        },
        { provide: DriverTripFeeService, useValue: driverTripFee },
        {
          provide: RidePaymentsService,
          useValue: { openForTrip: jest.fn().mockResolvedValue(undefined) },
        },
      ],
    }).compile();

    service = module.get(TripTimeService);
  });

  it('opens settlement only after completed/no-show bookings are finalized', async () => {
    bookings = [
      {
        id: 'b',
        tripId: 'trip-1',
        status: BookingStatus.IN_PROGRESS,
        passengerPresenceConfirmedAt: new Date(),
      },
    ];
    const payments = (service as any).ridePayments;
    payments.openForTrip.mockImplementation(async () => {
      expect(bookings[0].status).toBe(BookingStatus.COMPLETED);
    });
    await service.completeTrip('trip-1', 'driver-1', {});
    expect(payments.openForTrip).toHaveBeenCalledWith('trip-1');
    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });

  it('asks a fare only of passengers who rode — not of one who never confirmed boarding', async () => {
    bookings = [
      {
        id: 'b-rode',
        tripId: 'trip-1',
        status: BookingStatus.IN_PROGRESS,
        passengerPresenceConfirmedAt: new Date(),
      },
      {
        id: 'b-vouched',
        tripId: 'trip-1',
        status: BookingStatus.IN_PROGRESS,
        // The driver tapped «معي في السيارة».
        seats: [{ presenceConfirmedAt: new Date() }],
      },
      {
        id: 'b-silent',
        tripId: 'trip-1',
        status: BookingStatus.IN_PROGRESS,
        seats: [{ passengerSelfConfirmedAt: null, presenceConfirmedAt: null }],
      },
    ];

    await service.completeTrip('trip-1', 'driver-1', {});

    const status = (id: string) => bookings.find((b) => b.id === id)?.status;
    expect(status('b-rode')).toBe(BookingStatus.COMPLETED);
    expect(status('b-vouched')).toBe(BookingStatus.COMPLETED);
    // Not COMPLETED, so openForTrip (which asks COMPLETED bookings) skips it.
    expect(status('b-silent')).toBe(BookingStatus.NO_SHOW);
  });
});
