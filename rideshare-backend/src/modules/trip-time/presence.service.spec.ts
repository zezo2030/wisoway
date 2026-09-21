import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException } from '@nestjs/common';
import {
  BookingEntity,
  BookingStatus,
  BookingSeatEntity,
  PassengerDeclaredStatus,
  TripEntity,
} from '../../database/entities';
import { PresenceService } from './presence.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';

const SEAT_PRICE = 2;
const PERCENT = 10; // → 0.20 JOD per billable seat

/** departureTime far enough in the past that both windows are open. */
const DEPARTURE = new Date(Date.now() - 5 * 60 * 1000);

function makeSeat(
  overrides: Partial<BookingSeatEntity> = {},
): BookingSeatEntity {
  return Object.assign(new BookingSeatEntity(), {
    id: `seat-${Math.random().toString(36).slice(2, 8)}`,
    bookingId: 'b1',
    seatNumber: '1A',
    isMainBooker: true,
    displayName: 'أحمد',
    gender: 'male',
    presenceConfirmedAt: null,
    markedAbsentAt: null,
    passengerSelfConfirmedAt: null,
    passengerDeclaredStatus: null,
    autoFlaggedAbsentAt: null,
    absenceReason: null,
    billableOverride: null,
    presenceDisputedAt: null,
    presenceResolvedBy: null,
    presenceResolutionNote: null,
    presenceUpdatedAt: null,
    createdAt: new Date(),
    ...overrides,
  });
}

function makeBooking(seats: BookingSeatEntity[]): BookingEntity {
  return {
    id: 'b1',
    tripId: 't1',
    userId: 'u-passenger',
    status: BookingStatus.CONFIRMED,
    seats,
    passengerPresenceConfirmedAt: null,
    driverConfirmedPassengerAt: null,
    driverMarkedAbsentAt: null,
  } as unknown as BookingEntity;
}

function makeTrip(overrides: Partial<TripEntity> = {}): TripEntity {
  return {
    id: 't1',
    driverId: 'u-driver',
    departureTime: DEPARTURE,
    totalSeats: 4,
    price: String(SEAT_PRICE),
    currency: 'JOD',
    toName: 'إربد',
    presenceSettledAt: null,
    presenceReviewFlagged: false,
    billableSeatCount: null,
    capturedFeeAmount: null,
    driverFeeHoldId: 'hold-1',
    ...overrides,
  } as TripEntity;
}

describe('PresenceService', () => {
  let service: PresenceService;
  let tripRepo: any;
  let bookingRepo: any;
  let seatRepo: any;

  beforeEach(async () => {
    tripRepo = {
      findOne: jest.fn(),
      save: jest.fn(async (t: TripEntity) => t),
      manager: {
        getRepository: jest.fn(() => ({ find: jest.fn(async () => []) })),
      },
    };
    bookingRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn(async (b: BookingEntity) => b),
    };
    seatRepo = { save: jest.fn(async (s: BookingSeatEntity) => s) };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PresenceService,
        { provide: getRepositoryToken(TripEntity), useValue: tripRepo },
        { provide: getRepositoryToken(BookingEntity), useValue: bookingRepo },
        { provide: getRepositoryToken(BookingSeatEntity), useValue: seatRepo },
        {
          provide: NotificationsService,
          useValue: { create: jest.fn(async () => ({})) },
        },
        {
          provide: PlatformPricingService,
          useValue: {
            getActiveFeeRow: jest.fn(async () => null),
            driverUnlockPricing: jest.fn(() => ({
              driverUnlockPercent: PERCENT,
              seatPrice: SEAT_PRICE,
              currency: 'JOD',
              feeAmount: 0.8,
              legacyFlatFeeAmount: 0,
              totalSeats: 4,
            })),
          },
        },
      ],
    }).compile();

    service = module.get(PresenceService);
  });

  // ── The resolution table (plan §4.1) ────────────────────────────────────

  describe('driver decision resolution', () => {
    async function runDriverConfirm(
      seat: BookingSeatEntity,
      present: boolean,
    ): Promise<BookingSeatEntity> {
      const trip = makeTrip();
      const booking = makeBooking([seat]);
      tripRepo.findOne.mockResolvedValue(trip);
      bookingRepo.find.mockResolvedValue([booking]);

      await service.driverConfirm('t1', 'u-driver', {
        entries: [{ bookingId: 'b1', seatNumber: '1A', present }],
      });
      return seat;
    }

    it('records the driver presence decision without self-confirming the passenger', async () => {
      const seat = await runDriverConfirm(makeSeat(), true);
      expect(seat.presenceConfirmedAt).toBeTruthy();
      expect(seat.markedAbsentAt).toBeNull();
      expect(seat.passengerSelfConfirmedAt).toBeNull();
      expect(seat.billableOverride).toBeNull();
    });

    it('exempts a seat the driver explicitly marks absent', async () => {
      const seat = await runDriverConfirm(makeSeat(), false);
      expect(seat.markedAbsentAt).toBeTruthy();
      expect(seat.billableOverride).toBe(false);
      expect(seat.absenceReason).toBe('no_show');
    });

    it('KEEPS a seat billable when the driver contradicts a self-confirmed passenger', async () => {
      const seat = await runDriverConfirm(
        makeSeat({ passengerSelfConfirmedAt: new Date() }),
        false,
      );
      expect(seat.billableOverride).toBe(true);
      expect(seat.presenceDisputedAt).toBeTruthy();
    });

    it('clears the absence override when the driver later vouches for a passenger', async () => {
      const seat = await runDriverConfirm(
        makeSeat({
          passengerDeclaredStatus: PassengerDeclaredStatus.NOT_RIDING,
          billableOverride: false,
        }),
        true,
      );
      expect(seat.billableOverride).toBeNull();
    });
  });

  describe('passenger declaration', () => {
    async function runDeclare(
      seat: BookingSeatEntity,
      status: PassengerDeclaredStatus,
    ) {
      const trip = makeTrip();
      const booking = makeBooking([seat]);
      (booking as any).trip = trip;
      bookingRepo.findOne.mockResolvedValue(booking);
      await service.passengerDeclare('b1', 'u-passenger', { status });
      return seat;
    }

    it('records self-confirmation as the billable presence signal', async () => {
      const seat = await runDeclare(
        makeSeat(),
        PassengerDeclaredStatus.IN_VEHICLE,
      );
      expect(seat.passengerSelfConfirmedAt).toBeTruthy();
      expect(seat.billableOverride).not.toBe(false);
    });

    it('raises a dispute when the passenger contradicts an earlier driver absence', async () => {
      const seat = await runDeclare(
        makeSeat({ billableOverride: false, markedAbsentAt: new Date() }),
        PassengerDeclaredStatus.IN_VEHICLE,
      );
      expect(seat.billableOverride).toBe(true);
      expect(seat.presenceDisputedAt).toBeTruthy();
    });

    it('"on my way" does not create a self-confirmation', async () => {
      const seat = await runDeclare(
        makeSeat(),
        PassengerDeclaredStatus.ON_MY_WAY,
      );
      expect(seat.passengerSelfConfirmedAt).toBeNull();
      expect(seat.billableOverride).toBeNull();
    });

    it('"not riding" exempts the seat only while the driver has not vouched', async () => {
      const exempt = await runDeclare(
        makeSeat(),
        PassengerDeclaredStatus.NOT_RIDING,
      );
      expect(exempt.billableOverride).toBe(false);

      const vouched = await runDeclare(
        makeSeat({ presenceConfirmedAt: new Date() }),
        PassengerDeclaredStatus.NOT_RIDING,
      );
      expect(vouched.billableOverride).toBeNull();
    });
  });

  // ── Settlement ──────────────────────────────────────────────────────────

  describe('settleTripPresence', () => {
    function arrangeSeats(seats: BookingSeatEntity[]) {
      tripRepo.findOne.mockResolvedValue(makeTrip());
      bookingRepo.find.mockResolvedValue([makeBooking(seats)]);
    }

    it('records presence without moving any money', async () => {
      const trip = makeTrip();
      tripRepo.findOne.mockResolvedValue(trip);
      bookingRepo.find.mockResolvedValue([
        makeBooking([
          makeSeat({ passengerSelfConfirmedAt: new Date() }),
          makeSeat({ seatNumber: '1B', billableOverride: false }),
          makeSeat({
            seatNumber: '1C',
            presenceConfirmedAt: new Date(),
          }),
        ]),
      ]);

      const outcome = await service.settleTripPresence('t1');

      // Nothing was ever charged on this trip, so nothing to report.
      expect(outcome.captured).toBe(0);
      expect(outcome.released).toBe(0);
      expect(outcome.billableSeats).toBe(1);
      expect(trip.presenceSettledAt).toBeInstanceOf(Date);
    });

    it('leaves capturedFeeAmount alone — it belongs to the trip-start charge', async () => {
      const trip = makeTrip({ capturedFeeAmount: '1.60' });
      tripRepo.findOne.mockResolvedValue(trip);
      bookingRepo.find.mockResolvedValue([
        makeBooking([makeSeat({ passengerSelfConfirmedAt: new Date() })]),
      ]);

      await service.settleTripPresence('t1');

      expect(trip.capturedFeeAmount).toBe('1.60');
    });

    // The driver's trip summary renders `settlement.captured` ahead of the
    // trip's own capturedFeeAmount, so a 0 here is not "unknown" — it is a
    // claim that the fee was 0.00 on a trip that was just debited 1.60.
    it('reports the fee already charged at trip start on a fresh settlement', async () => {
      tripRepo.findOne.mockResolvedValue(
        makeTrip({ capturedFeeAmount: '1.60' }),
      );
      bookingRepo.find.mockResolvedValue([
        makeBooking([makeSeat({ passengerSelfConfirmedAt: new Date() })]),
      ]);

      const outcome = await service.settleTripPresence('t1');

      expect(outcome.captured).toBe(1.6);
    });

    it('reports the same captured amount whether or not it settled before', async () => {
      const fresh = makeTrip({ capturedFeeAmount: '1.60' });
      tripRepo.findOne.mockResolvedValue(fresh);
      bookingRepo.find.mockResolvedValue([
        makeBooking([makeSeat({ passengerSelfConfirmedAt: new Date() })]),
      ]);
      const first = await service.settleTripPresence('t1');

      tripRepo.findOne.mockResolvedValue(
        makeTrip({
          capturedFeeAmount: '1.60',
          presenceSettledAt: new Date(),
          billableSeatCount: 1,
        }),
      );
      const second = await service.settleTripPresence('t1');

      expect(second.captured).toBe(first.captured);
    });

    it('flags a trip for review when seats existed but nobody confirmed', async () => {
      arrangeSeats([
        makeSeat({ billableOverride: false }),
        makeSeat({ seatNumber: '1B', billableOverride: false }),
      ]);

      await service.settleTripPresence('t1');

      expect(tripRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ presenceReviewFlagged: true }),
      );
    });

    it('is idempotent — a second settlement moves no further money', async () => {
      tripRepo.findOne.mockResolvedValue(
        makeTrip({
          presenceSettledAt: new Date(),
          billableSeatCount: 2,
          capturedFeeAmount: '0.40',
        }),
      );

      const out = await service.settleTripPresence('t1');

      expect(out.applied).toBe(false);
      expect(out.captured).toBe(0.4);
      expect(out.released).toBe(0);
    });

    it('only counts seats from confirmed/in-progress/completed bookings', async () => {
      tripRepo.findOne.mockResolvedValue(makeTrip());
      bookingRepo.find.mockResolvedValue([
        makeBooking([makeSeat({ passengerSelfConfirmedAt: new Date() })]),
      ]);

      await service.settleTripPresence('t1');

      // The status filter is what keeps cancelled/rejected/pending bookings out
      // of the fee. Assert the exact set rather than just "a filter exists".
      const where = bookingRepo.find.mock.calls[0][0].where;
      expect(where.tripId).toBe('t1');
      expect(where.status._value).toEqual([
        BookingStatus.CONFIRMED,
        BookingStatus.IN_PROGRESS,
        BookingStatus.COMPLETED,
      ]);
      expect(where.status._value).not.toContain(BookingStatus.CANCELLED);
    });
  });

  // ── Windows ─────────────────────────────────────────────────────────────

  it('rejects driver confirmation before the window opens', async () => {
    tripRepo.findOne.mockResolvedValue(
      makeTrip({ departureTime: new Date(Date.now() + 6 * 60 * 60 * 1000) }),
    );

    await expect(
      service.driverConfirm('t1', 'u-driver', {
        entries: [{ bookingId: 'b1', seatNumber: '1A', present: true }],
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects driver confirmation once the trip is settled', async () => {
    tripRepo.findOne.mockResolvedValue(
      makeTrip({ presenceSettledAt: new Date() }),
    );

    await expect(
      service.driverConfirm('t1', 'u-driver', {
        entries: [{ bookingId: 'b1', seatNumber: '1A', present: true }],
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});
