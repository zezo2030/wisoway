import { PassengerLocationService } from './passenger-location.service';
import {
  BookingSeatEntity,
  BookingStatus,
  PassengerDeclaredStatus,
  seatCountsForCommission,
  TripStatus,
  TripType,
} from '../../database/entities';

const START = { lat: 31.95, lng: 35.91 };
/** About 111 m of latitude. */
const STEP = 0.001;

describe('PassengerLocationService', () => {
  let now: number;

  const build = (seats: Partial<BookingSeatEntity>[] = []) => {
    const trip = {
      id: 't1',
      driverId: 'd1',
      status: TripStatus.IN_PROGRESS,
      tripType: TripType.SCHEDULED,
      lastDriverLocationLat: START.lat,
      lastDriverLocationLng: START.lng,
      lastDriverLocationAt: new Date(now),
    };
    const booking = {
      id: 'b1',
      seats,
      status: BookingStatus.CONFIRMED,
      locationVerifiedAt: null as Date | null,
      locationMatchStartedAt: null as Date | null,
      locationMatchLat: null as number | null,
      locationMatchLng: null as number | null,
      locationMatchMeters: 0,
    };
    const tripRepo = { findOne: jest.fn().mockResolvedValue(trip) };
    const bookingRepo = {
      find: jest.fn().mockResolvedValue([booking]),
      save: jest.fn().mockResolvedValue(undefined),
    };
    const seatRepo = { save: jest.fn().mockResolvedValue(undefined) };
    const userRepo = { find: jest.fn().mockResolvedValue([{ id: 'admin' }]) };
    const notifications = { create: jest.fn().mockResolvedValue(undefined) };
    const service = new PassengerLocationService(
      tripRepo as never,
      bookingRepo as never,
      seatRepo as never,
      userRepo as never,
      notifications as never,
    );

    /** One reading: the car moved, a minute passed, the phone reported. */
    const ride = async (index: number, offset = 0, accuracyMeters = 10) => {
      const lat = START.lat + index * STEP * 2;
      trip.lastDriverLocationLat = lat;
      trip.lastDriverLocationAt = new Date(now);
      const result = await service.record('p1', {
        tripId: 't1',
        latitude: lat + offset,
        longitude: START.lng,
        accuracyMeters,
      });
      now += 60_000;
      jest.setSystemTime(now);
      return result;
    };
    return { service, trip, booking, bookingRepo, notifications, ride };
  };

  beforeEach(() => {
    now = Date.UTC(2026, 10, 6, 12);
    jest.useFakeTimers({ now });
  });

  afterEach(() => jest.useRealTimers());

  it('proves the ride once the two travel together far and long enough', async () => {
    const { booking, ride } = build();

    for (let i = 0; i < 5; i++) await ride(i);
    expect(booking.locationVerifiedAt).toBeNull();

    const result = await ride(5);
    expect(result).toEqual({ tracking: false, verified: true });
    expect(booking.locationVerifiedAt).not.toBeNull();
  });

  it('never stores where the passenger was', async () => {
    const { booking, ride } = build();
    await ride(0, STEP);

    expect(booking.locationMatchLat).toBe(START.lat);
  });

  it('does not count two phones sitting together in a parked car', async () => {
    const { booking, ride } = build();

    for (let i = 0; i < 10; i++) await ride(0);

    expect(booking.locationVerifiedAt).toBeNull();
    expect(booking.locationMatchMeters).toBe(0);
  });

  it('starts over when they separate', async () => {
    const { booking, ride } = build();

    for (let i = 0; i < 4; i++) await ride(i);
    expect(booking.locationMatchMeters).toBeGreaterThan(0);

    await ride(4, STEP * 10);

    expect(booking.locationMatchMeters).toBe(0);
    expect(booking.locationMatchStartedAt).toBeNull();
  });

  it('ignores a reading too inaccurate to prove anything', async () => {
    const { booking, ride } = build();

    await ride(0, 0, 500);

    expect(booking.locationMatchStartedAt).toBeNull();
  });

  it('ignores a spoofed position', async () => {
    const { service, booking } = build();

    await service.record('p1', {
      tripId: 't1',
      latitude: START.lat,
      longitude: START.lng,
      isMockLocation: true,
    });

    expect(booking.locationMatchStartedAt).toBeNull();
  });

  it('compares nothing against a stale driver position', async () => {
    const { service, trip, booking } = build();
    trip.lastDriverLocationAt = new Date(now - 5 * 60_000);

    const result = await service.record('p1', {
      tripId: 't1',
      latitude: START.lat,
      longitude: START.lng,
    });

    expect(result).toEqual({ tracking: true, verified: false });
    expect(booking.locationMatchStartedAt).toBeNull();
  });

  it.each([
    ['instant rides', { tripType: TripType.INSTANT }],
    ['a finished trip', { status: TripStatus.COMPLETED }],
  ])('tells the app to stop on %s', async (_name, change) => {
    const { service, trip } = build();
    Object.assign(trip, change);

    await expect(
      service.record('p1', {
        tripId: 't1',
        latitude: START.lat,
        longitude: START.lng,
      }),
    ).resolves.toEqual({ tracking: false, verified: false });
  });

  it('sends a contradicted "did not ride" to the admins', async () => {
    const seat = {
      passengerDeclaredStatus: PassengerDeclaredStatus.NOT_RIDING,
      presenceDisputedAt: null,
    } as Partial<BookingSeatEntity>;
    const { notifications, ride } = build([seat]);

    for (let i = 0; i < 6; i++) await ride(i);

    expect(seat.presenceDisputedAt).not.toBeNull();
    expect(notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'presence_conflict_admin' }),
    );
  });
});

describe('seatCountsForCommission — a companion who said they stayed', () => {
  it('is not counted because the booker rode', () => {
    expect(
      seatCountsForCommission(
        {
          isMainBooker: false,
          markedAbsentAt: null,
          passengerSelfConfirmedAt: null,
          passengerDeclaredStatus: 'not_riding',
          billableOverride: false,
        },
        true,
      ),
    ).toBe(false);
  });
});

describe('seatCountsForCommission', () => {
  const seat = (over: Partial<BookingSeatEntity> = {}) => ({
    isMainBooker: true,
    markedAbsentAt: null,
    passengerSelfConfirmedAt: null,
    passengerDeclaredStatus: null,
    billableOverride: null,
    ...over,
  });

  it('still needs the passenger confirmation without location proof', () => {
    expect(seatCountsForCommission(seat(), false)).toBe(false);
    expect(
      seatCountsForCommission(
        seat({ passengerSelfConfirmedAt: new Date() }),
        false,
      ),
    ).toBe(true);
  });

  it('counts an unconfirmed seat with location proof', () => {
    expect(seatCountsForCommission(seat(), true)).toBe(true);
  });

  it('counts the booker even after "did not ride"', () => {
    expect(
      seatCountsForCommission(seat({ billableOverride: false }), true),
    ).toBe(true);
  });

  it('lets the driver mark only a companion absent', () => {
    const absent = { markedAbsentAt: new Date() };
    expect(seatCountsForCommission(seat(absent), true)).toBe(true);
    expect(
      seatCountsForCommission(seat({ ...absent, isMainBooker: false }), true),
    ).toBe(false);
  });
});
