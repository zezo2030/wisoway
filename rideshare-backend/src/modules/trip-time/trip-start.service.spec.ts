import { ConflictException, ForbiddenException } from '@nestjs/common';
import { FindOperator } from 'typeorm';
import { TripStatus } from '../../database/entities/shared.enums';
import { BookingStatus } from '../../database/entities/booking.entity';
import { TripStartService } from './trip-start.service';

/** Does [value] satisfy a TypeORM where-clause entry (plain, In, IsNull)? */
function matches(value: unknown, cond: unknown): boolean {
  if (cond instanceof FindOperator) {
    if (cond.type === 'in') return (cond.value as unknown[]).includes(value);
    if (cond.type === 'isNull') return value == null;
    return false;
  }
  return value === cond;
}

describe('TripStartService', () => {
  const departure = new Date('2026-10-17T10:00:00Z');
  let trip: Record<string, any>;
  let bookings: Array<Record<string, any>>;
  let notifications: { create: jest.Mock; getPreferredLocale: jest.Mock };
  let driverTripFee: { chargeAtTripStart: jest.Mock };
  let autoComplete: { add: jest.Mock };
  let service: TripStartService;

  const sent = (type: string) =>
    notifications.create.mock.calls
      .map(([n]) => n as { userId: string; type: string })
      .filter((n) => n.type === type)
      .map((n) => n.userId);

  beforeEach(() => {
    trip = {
      id: 't1',
      driverId: 'd1',
      tripType: 'scheduled',
      status: TripStatus.PUBLISHED,
      departureTime: departure,
      toName: 'تبوك',
      tripStartedAt: null,
      boardingPromptSentAt: null,
    };
    bookings = [
      { id: 'b1', userId: 'p1', status: BookingStatus.CONFIRMED },
      { id: 'b2', userId: 'p2', status: BookingStatus.CONFIRMED },
    ];
    const tripRepo = {
      findOne: jest.fn(async () => ({ ...trip })),
      update: jest.fn(async (where: Record<string, unknown>, patch: object) => {
        const hit = Object.entries(where).every(([k, c]) =>
          matches(trip[k], c),
        );
        if (hit) Object.assign(trip, patch);
        return { affected: hit ? 1 : 0 };
      }),
    };
    const bookingRepo = {
      find: jest.fn(async ({ where }: { where: { status: string } }) =>
        bookings.filter((b) => b.status === where.status),
      ),
      update: jest.fn(async (where: { id: FindOperator<string> }, patch) => {
        for (const b of bookings) {
          if (matches(b.id, where.id)) Object.assign(b, patch);
        }
        return { affected: 1 };
      }),
    };
    notifications = {
      create: jest.fn().mockResolvedValue({}),
      getPreferredLocale: jest.fn().mockResolvedValue('ar'),
    };
    driverTripFee = {
      chargeAtTripStart: jest
        .fn()
        .mockResolvedValue({ charged: 1.6, currency: 'SAR' }),
    };
    autoComplete = { add: jest.fn() };
    service = new TripStartService(
      tripRepo as never,
      bookingRepo as never,
      autoComplete as never,
      notifications as never,
      driverTripFee as never,
    );
  });

  describe('at departure', () => {
    it('waits when nobody is on board, and asks each passenger once', async () => {
      await service.onDeparture('t1');

      expect(trip.status).toBe(TripStatus.PUBLISHED);
      expect(driverTripFee.chargeAtTripStart).not.toHaveBeenCalled();
      expect(sent('presence_prompt')).toEqual(['p1', 'p2']);
      expect(sent('trip_awaiting_boarding')).toEqual(['d1']);

      // The lifecycle sweep runs it again: no second round of prompts.
      notifications.create.mockClear();
      await service.onDeparture('t1');
      expect(notifications.create).not.toHaveBeenCalled();
    });

    it('starts when a passenger already confirmed boarding', async () => {
      bookings[0].passengerPresenceConfirmedAt = new Date();

      await service.onDeparture('t1');

      expect(trip.status).toBe(TripStatus.IN_PROGRESS);
      expect(
        bookings.every((b) => b.status === BookingStatus.IN_PROGRESS),
      ).toBe(true);
      expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledTimes(1);
      // The one who confirmed hears it started; the other is asked to confirm.
      expect(sent('trip_started')).toEqual(['d1', 'p1']);
      expect(sent('presence_prompt')).toEqual(['p2']);
      expect(autoComplete.add).toHaveBeenCalled();
    });

    it('starts a trip nobody booked — there is no one to wait for', async () => {
      bookings = [];

      await service.onDeparture('t1');

      expect(trip.status).toBe(TripStatus.IN_PROGRESS);
    });

    it('leaves a cancelled trip alone', async () => {
      trip.status = TripStatus.CANCELLED;

      await service.onDeparture('t1');

      expect(trip.status).toBe(TripStatus.CANCELLED);
      expect(notifications.create).not.toHaveBeenCalled();
    });
  });

  describe('a passenger confirms boarding', () => {
    it('starts the waiting trip from departure on', async () => {
      await service.onPassengerBoarded(
        't1',
        new Date(departure.getTime() + 60_000),
      );

      expect(trip.status).toBe(TripStatus.IN_PROGRESS);
      expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledTimes(1);
    });

    it('does not start it before departure', async () => {
      await service.onPassengerBoarded(
        't1',
        new Date(departure.getTime() - 60_000),
      );

      expect(trip.status).toBe(TripStatus.PUBLISHED);
    });

    it('starts it only once when two confirm together', async () => {
      const at = new Date(departure.getTime() + 60_000);
      await Promise.all([
        service.onPassengerBoarded('t1', at),
        service.onPassengerBoarded('t1', at),
      ]);

      expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledTimes(1);
    });
  });

  describe('the driver presses «بدء الرحلة»', () => {
    it('starts the trip from 30 minutes before departure', async () => {
      await service.startByDriver(
        't1',
        'd1',
        new Date(departure.getTime() - 10 * 60_000),
      );

      expect(trip.status).toBe(TripStatus.IN_PROGRESS);
    });

    it('refuses earlier than that', async () => {
      await expect(
        service.startByDriver(
          't1',
          'd1',
          new Date(departure.getTime() - 60 * 60_000),
        ),
      ).rejects.toThrow(ConflictException);
      expect(trip.status).toBe(TripStatus.PUBLISHED);
    });

    it("refuses another driver's trip", async () => {
      await expect(
        service.startByDriver('t1', 'd2', departure),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  it('still starts the trip when the fee charge throws', async () => {
    driverTripFee.chargeAtTripStart.mockRejectedValue(new Error('ledger down'));
    bookings = [];

    await service.onDeparture('t1');

    expect(trip.status).toBe(TripStatus.IN_PROGRESS);
  });
});
