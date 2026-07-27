import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { ConflictException, NotFoundException } from '@nestjs/common';
import {
  BookingEntity,
  BookingStatus,
  BookingSeatEntity,
  PassengerDeclaredStatus,
  TripEntity,
} from '../../database/entities';
import { PresenceService } from './presence.service';
import { NotificationsService } from '../notifications/notifications.service';
import { WalletHoldService } from '../wallet/wallet-hold.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';

const SEAT_PRICE = 2;
const PERCENT = 10; // → 0.20 JOD per billable seat

/** departureTime far enough in the past that both windows are open. */
const DEPARTURE = new Date(Date.now() - 5 * 60 * 1000);

function makeSeat(overrides: Partial<BookingSeatEntity> = {}): BookingSeatEntity {
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
  let walletHolds: jest.Mocked<Partial<WalletHoldService>>;

  beforeEach(async () => {
    tripRepo = {
      findOne: jest.fn(),
      save: jest.fn(async (t: TripEntity) => t),
      manager: { getRepository: jest.fn(() => ({ find: jest.fn(async () => []) })) },
    };
    bookingRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      save: jest.fn(async (b: BookingEntity) => b),
    };
    seatRepo = { save: jest.fn(async (s: BookingSeatEntity) => s) };

    walletHolds = {
      getActiveHold: jest.fn(async () => ({
        id: 'hold-1',
        currency: 'JOD',
        metadata: { percent: PERCENT, seatPrice: SEAT_PRICE },
      })) as any,
      settleHold: jest.fn(async ({ captureAmount }: any) => ({
        hold: {} as any,
        captured: captureAmount,
        released: Math.round((0.8 - captureAmount) * 100) / 100,
        currency: 'JOD',
        applied: true,
      })),
    };

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
        { provide: WalletHoldService, useValue: walletHolds },
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

    it('charges nothing when no passenger confirms presence', async () => {
      arrangeSeats([makeSeat(), makeSeat({ seatNumber: '1B' })]);

      const out = await service.settleTripPresence('t1');

      expect(out.billableSeats).toBe(0);
      expect(out.captured).toBe(0);
    });

    it('charges only for passengers who explicitly confirmed presence', async () => {
      arrangeSeats([
        makeSeat({ passengerSelfConfirmedAt: new Date() }),
        makeSeat({ seatNumber: '1B', billableOverride: false }),
        makeSeat({
          seatNumber: '1C',
          presenceConfirmedAt: new Date(),
        }),
      ]);

      const out = await service.settleTripPresence('t1');

      expect(out.billableSeats).toBe(1);
      expect(out.captured).toBe(0.2);
      expect(out.released).toBe(0.6);
    });

    it('does not charge seats that were only auto-flagged by the no-show detector', async () => {
      arrangeSeats([
        makeSeat({ autoFlaggedAbsentAt: new Date() }),
        makeSeat({ seatNumber: '1B', autoFlaggedAbsentAt: new Date() }),
      ]);

      const out = await service.settleTripPresence('t1');

      expect(out.billableSeats).toBe(0);
      expect(out.captured).toBe(0);
    });

    it('captures nothing and flags for review when no seat is confirmed', async () => {
      arrangeSeats([
        makeSeat({ billableOverride: false }),
        makeSeat({ seatNumber: '1B', billableOverride: false }),
      ]);

      const out = await service.settleTripPresence('t1');

      expect(out.billableSeats).toBe(0);
      expect(out.captured).toBe(0);
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
      expect(walletHolds.settleHold).not.toHaveBeenCalled();
    });

    it('still records a settlement when no hold exists (free lifetime trip)', async () => {
      arrangeSeats([makeSeat()]);
      (walletHolds.settleHold as jest.Mock).mockRejectedValueOnce(
        new NotFoundException('HOLD_NOT_FOUND'),
      );

      const out = await service.settleTripPresence('t1');

      expect(out.captured).toBe(0);
      expect(tripRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ presenceSettledAt: expect.any(Date) }),
      );
    });

    it('does not mark the trip settled when wallet settlement fails', async () => {
      arrangeSeats([makeSeat({ passengerSelfConfirmedAt: new Date() })]);
      (walletHolds.settleHold as jest.Mock).mockRejectedValueOnce(
        new Error('wallet unavailable'),
      );

      await expect(service.settleTripPresence('t1')).rejects.toThrow(
        'wallet unavailable',
      );
      expect(tripRepo.save).not.toHaveBeenCalled();
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
