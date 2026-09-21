import { FindOperator } from 'typeorm';
import { TripPassengerSummaryService } from './trip-passenger-summary.service';
import { BookingStatus } from '../../database/entities/booking.entity';

type Row = {
  tripId: string;
  status: string;
  seatCount: number;
  user?: { photoUrl: string | null } | null;
  createdAt: Date;
};

const row = (overrides: Partial<Row> = {}): Row => ({
  tripId: 'trip-1',
  status: BookingStatus.CONFIRMED,
  seatCount: 1,
  user: { photoUrl: 'https://cdn.example.com/a.jpg' },
  createdAt: new Date('2026-01-01T10:00:00Z'),
  ...overrides,
});

/**
 * Minimal in-memory stand-in for the bookings repository: it honours the
 * `where` clause (including `In(...)`) so a missing status filter or a missing
 * trip filter fails the tests instead of passing silently.
 */
function fakeBookingRepo(rows: Row[]) {
  return {
    find: jest.fn(async (options: any) => {
      const where = options?.where ?? {};
      const matches = rows.filter((candidate) =>
        Object.entries(where).every(([column, condition]) => {
          const value = (candidate as any)[column];
          if (condition instanceof FindOperator) {
            return (condition.value as unknown[]).includes(value);
          }
          return condition === value;
        }),
      );
      return matches.sort(
        (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
      );
    }),
  } as any;
}

describe('TripPassengerSummaryService', () => {
  it('returns the booked seat total and passenger avatars per trip', async () => {
    const repo = fakeBookingRepo([
      row({ tripId: 'trip-1', seatCount: 2, user: { photoUrl: 'a.jpg' } }),
      row({ tripId: 'trip-1', seatCount: 1, user: { photoUrl: 'b.jpg' } }),
      row({ tripId: 'trip-2', seatCount: 3, user: { photoUrl: 'c.jpg' } }),
    ]);
    const service = new TripPassengerSummaryService(repo);

    const summary = await service.forTrips(['trip-1', 'trip-2']);

    expect(summary.get('trip-1')).toEqual({
      bookedSeats: 3,
      passengerAvatars: ['a.jpg', 'b.jpg'],
    });
    expect(summary.get('trip-2')).toEqual({
      bookedSeats: 3,
      passengerAvatars: ['c.jpg'],
    });
  });

  it('ignores bookings that never took a seat', async () => {
    const repo = fakeBookingRepo([
      row({ seatCount: 2 }),
      row({ status: BookingStatus.CANCELLED, seatCount: 4 }),
      row({ status: BookingStatus.REJECTED, seatCount: 4 }),
      row({ status: BookingStatus.PENDING, seatCount: 4 }),
      row({ status: BookingStatus.NO_SHOW, seatCount: 4 }),
    ]);
    const service = new TripPassengerSummaryService(repo);

    const summary = await service.forTrips(['trip-1']);

    expect(summary.get('trip-1')?.bookedSeats).toBe(2);
  });

  it('counts a passenger without a photo but shows no avatar for them', async () => {
    const repo = fakeBookingRepo([
      row({ seatCount: 1, user: { photoUrl: null } }),
      row({ seatCount: 2, user: { photoUrl: '' } }),
      row({ seatCount: 1, user: { photoUrl: 'c.jpg' } }),
    ]);
    const service = new TripPassengerSummaryService(repo);

    const summary = await service.forTrips(['trip-1']);

    expect(summary.get('trip-1')).toEqual({
      bookedSeats: 4,
      passengerAvatars: ['c.jpg'],
    });
  });

  it('caps the avatar list at three so the card stays readable', async () => {
    const repo = fakeBookingRepo(
      ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg', 'e.jpg'].map((photoUrl, index) =>
        row({
          user: { photoUrl },
          createdAt: new Date(Date.UTC(2026, 0, 1, index)),
        }),
      ),
    );
    const service = new TripPassengerSummaryService(repo);

    const summary = await service.forTrips(['trip-1']);

    expect(summary.get('trip-1')).toEqual({
      bookedSeats: 5,
      passengerAvatars: ['a.jpg', 'b.jpg', 'c.jpg'],
    });
  });

  it('omits trips that have no live bookings', async () => {
    const repo = fakeBookingRepo([row({ tripId: 'trip-1' })]);
    const service = new TripPassengerSummaryService(repo);

    const summary = await service.forTrips(['trip-1', 'trip-empty']);

    expect(summary.has('trip-empty')).toBe(false);
  });

  it('does not query at all for an empty trip list', async () => {
    const repo = fakeBookingRepo([row()]);
    const service = new TripPassengerSummaryService(repo);

    const summary = await service.forTrips([]);

    expect(summary.size).toBe(0);
    expect(repo.find).not.toHaveBeenCalled();
  });
});
