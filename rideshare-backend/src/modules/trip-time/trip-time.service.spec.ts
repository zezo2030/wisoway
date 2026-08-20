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
          useValue: { create: jest.fn().mockResolvedValue({}) },
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
      ],
    }).compile();

    service = module.get(TripTimeService);
  });

  it('charges a trip whose start-time debit never landed', async () => {
    trip.driverWalletChargeApplied = false;

    await service.completeTrip('trip-1', 'driver-1', {});

    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledWith(trip);
  });

  it('does not re-charge a trip already stamped', async () => {
    trip.driverWalletChargeApplied = true;

    await service.completeTrip('trip-1', 'driver-1', {});

    expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
  });

  it('still settles presence when the recovered charge throws', async () => {
    trip.driverWalletChargeApplied = false;
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));

    await expect(
      service.completeTrip('trip-1', 'driver-1', {}),
    ).resolves.toBeDefined();

    expect(presenceService.settleTripPresence).toHaveBeenCalledWith('trip-1');
  });

  it('logs a distinguishable recovery message when the sweep charges a trip trip-start missed', async () => {
    trip.driverWalletChargeApplied = false;
    const logSpy = jest.spyOn((service as any).logger, 'log');

    await service.completeTrip('trip-1', 'driver-1', {});

    expect(logSpy).toHaveBeenCalledWith(expect.stringContaining('RECOVERED'));
  });

  it('logs at error level, with the trip id and error, when the sweep charge attempt fails', async () => {
    trip.driverWalletChargeApplied = false;
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));
    const errorSpy = jest.spyOn((service as any).logger, 'error');

    await service.completeTrip('trip-1', 'driver-1', {});

    const call = errorSpy.mock.calls.find((c) =>
      String(c[0]).includes('reconcil'),
    );
    expect(call).toBeDefined();
    expect(String(call?.[0])).toContain('trip-1');
    expect(String(call?.[0])).toContain('ledger down');
  });
  // Regression: the sweep used to run AFTER the no-show pass and the
  // IN_PROGRESS -> COMPLETED pass. chargeAtTripStart decides whether a fee is
  // owed by counting bookings In([CONFIRMED, IN_PROGRESS]), so by then there
  // were none: it took the 'no-bookings' branch, wrote a 0.00 audit row and
  // stamped the trip, which also hid it from the reconciliation cron
  // (driverWalletChargeApplied IS NOT TRUE). The rescue path permanently zeroed
  // the fee it exists to recover.
  it('charges before the booking flip — a real fee, not a no-bookings 0.00', async () => {
    trip.driverWalletChargeApplied = false;
    bookings = [
      { id: 'b-1', tripId: 'trip-1', status: BookingStatus.IN_PROGRESS },
    ];

    let outcome: any;
    let statusesWhenCharged: string[] = [];
    driverTripFee.chargeAtTripStart.mockImplementation(async (t: any) => {
      // Mirrors DriverTripFeeService: no CONFIRMED/IN_PROGRESS booking at the
      // moment of the call means no fee is owed at all.
      statusesWhenCharged = bookings.map((b) => b.status);
      const active = bookings.filter(
        (b) =>
          b.status === BookingStatus.CONFIRMED ||
          b.status === BookingStatus.IN_PROGRESS,
      );
      outcome =
        active.length === 0
          ? {
              tripId: t.id,
              charged: 0,
              pendingRemainder: 0,
              currency: 'JOD',
              applied: true,
              reason: 'no-bookings',
            }
          : {
              tripId: t.id,
              charged: 1.6,
              pendingRemainder: 0,
              currency: 'JOD',
              applied: true,
            };
      return outcome;
    });

    await service.completeTrip('trip-1', 'driver-1', {});

    expect(outcome.charged).toBeGreaterThan(0);
    expect(outcome.reason).not.toBe('no-bookings');
    expect(statusesWhenCharged).toContain(BookingStatus.IN_PROGRESS);
  });

  // The fee is charged on totalSeats, so a driver who marks everyone absent
  // still owes it — the no-show pass must not be able to zero it either.
  it('charges before the no-show pass empties the billable set', async () => {
    trip.driverWalletChargeApplied = false;
    bookings = [
      {
        id: 'b-1',
        tripId: 'trip-1',
        status: BookingStatus.IN_PROGRESS,
        seats: [],
      },
    ];

    let statusesWhenCharged: string[] = [];
    driverTripFee.chargeAtTripStart.mockImplementation(async () => {
      statusesWhenCharged = bookings.map((b) => b.status);
      return {
        tripId: 'trip-1',
        charged: 1.6,
        pendingRemainder: 0,
        currency: 'JOD',
        applied: true,
      };
    });

    await service.completeTrip('trip-1', 'driver-1', {
      noShowSeats: [{ bookingId: 'b-1', seatNumber: '1A' }],
    } as any);

    expect(statusesWhenCharged).not.toContain(BookingStatus.NO_SHOW);
  });

  it('still completes the bookings after the charge', async () => {
    trip.driverWalletChargeApplied = false;
    bookings = [
      { id: 'b-1', tripId: 'trip-1', status: BookingStatus.IN_PROGRESS },
    ];

    await service.completeTrip('trip-1', 'driver-1', {});

    expect(bookings[0].status).toBe(BookingStatus.COMPLETED);
  });
});
