import 'dotenv/config';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { DataSource } from 'typeorm';
import { TripEntity } from '../../src/database/entities/trip.entity';
import { BookingEntity } from '../../src/database/entities/booking.entity';
import { TripStartService } from '../../src/modules/trip-time/trip-start.service';
import { PreTripReminderJob } from '../../src/jobs/pre-trip-reminder.job';

/**
 * The reminders around a shared trip's time, against the real schema. Needs
 * the local Postgres; every row is made here and removed.
 */
describe('Shared trip reminders (real database)', () => {
  const database = new DataSource({
    type: 'postgres',
    host: process.env.POSTGRES_HOST,
    port: Number(process.env.POSTGRES_PORT),
    username: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB,
    entities: [path.join(__dirname, '../../src/database/entities/*.entity.ts')],
  });
  const users: string[] = [];
  const notifications = {
    create: jest.fn().mockResolvedValue({}),
    getPreferredLocale: jest.fn().mockResolvedValue('ar'),
  };
  let tripStart: TripStartService;
  let reminders: PreTripReminderJob;

  const sql = (query: string, params: unknown[] = []) =>
    database.query(query, params);

  const makeUser = async (role: string): Promise<string> => {
    const id = randomUUID();
    await sql(
      `INSERT INTO users (id, "phoneNumber", name, email, role)
       VALUES ($1, $2, 'Test', $3, $4)`,
      [
        id,
        `+9627${id.replace(/\D/g, '').slice(0, 8)}`,
        `${id}@example.com`,
        role,
      ],
    );
    users.push(id);
    return id;
  };

  /** A trip leaving at now + [departsIn], with one confirmed booking per passenger. */
  const makeTrip = async (
    departsIn: string,
    columns: Record<string, string> = {},
    passengers = 1,
  ) => {
    const driver = await makeUser('driver');
    const trip = randomUUID();
    await sql(
      `INSERT INTO trips (id, "driverId", "fromName", "toName", "fromPoint", "toPoint",
         "departureTime", price, status, "tripType")
       VALUES ($1, $2, 'A', 'B', ST_MakePoint(35, 31)::geography,
         ST_MakePoint(36, 32)::geography, now() + $3::interval, 5, 'published', 'scheduled')`,
      [trip, driver, departsIn],
    );
    for (const [column, ago] of Object.entries(columns)) {
      await sql(
        `UPDATE trips SET "${column}" = now() - $2::interval WHERE id = $1`,
        [trip, ago],
      );
    }
    const riders: string[] = [];
    for (let i = 0; i < passengers; i++) {
      const passenger = await makeUser('passenger');
      await sql(
        `INSERT INTO bookings (id, "tripId", "userId", status, "totalAmount")
         VALUES ($1, $2, $3, 'confirmed', 5)`,
        [randomUUID(), trip, passenger],
      );
      riders.push(passenger);
    }
    return { trip, driver, riders };
  };

  const sentTo = (type: string) =>
    notifications.create.mock.calls
      .map(([n]) => n as { userId: string; type: string })
      .filter((n) => n.type === type)
      .map((n) => n.userId);

  beforeAll(async () => {
    await database.initialize();
    tripStart = new TripStartService(
      database.getRepository(TripEntity),
      database.getRepository(BookingEntity),
      { add: jest.fn() } as never,
      notifications as never,
      { chargeAtTripStart: jest.fn() } as never,
    );
    reminders = new PreTripReminderJob(
      database.getRepository(TripEntity),
      database.getRepository(BookingEntity),
      notifications as never,
    );
  });

  beforeEach(() => notifications.create.mockClear());

  afterAll(async () => {
    await sql(
      `DELETE FROM bookings WHERE "userId" = ANY($1) OR "tripId" IN
         (SELECT id FROM trips WHERE "driverId" = ANY($1))`,
      [users],
    );
    await sql(`DELETE FROM trips WHERE "driverId" = ANY($1)`, [users]);
    await sql(`DELETE FROM users WHERE id = ANY($1)`, [users]);
    await database.destroy();
  });

  describe('a trip still waiting after departure', () => {
    it('reminds the driver to start it, and whoever has not confirmed, once per round', async () => {
      const { trip, driver, riders } = await makeTrip(
        '-6 minutes',
        { boardingPromptSentAt: '6 minutes' },
        2,
      );

      await tripStart.onDeparture(trip);

      expect(sentTo('trip_awaiting_boarding')).toEqual([driver]);
      expect(sentTo('presence_prompt').sort()).toEqual([...riders].sort());

      // The next sweep tick a moment later: nothing new.
      notifications.create.mockClear();
      await tripStart.onDeparture(trip);
      expect(notifications.create).not.toHaveBeenCalled();

      // Five minutes on: the next round.
      await tripStart.onDeparture(trip, new Date(Date.now() + 5 * 60_000));
      expect(sentTo('trip_awaiting_boarding')).toEqual([driver]);
    });

    it('does not nudge in the same tick as the departure prompt', async () => {
      const { trip, driver } = await makeTrip('-3 minutes');

      await tripStart.onDeparture(trip);

      // The departure prompt itself went out, and nothing on top of it.
      expect(sentTo('trip_awaiting_boarding')).toEqual([driver]);
      expect(notifications.create).toHaveBeenCalledTimes(2);
    });

    it('stops reminding an hour after departure', async () => {
      const { trip } = await makeTrip('-70 minutes', {
        boardingPromptSentAt: '70 minutes',
      });

      await tripStart.onDeparture(trip);

      expect(notifications.create).not.toHaveBeenCalled();
    });
  });

  describe('fifteen minutes before', () => {
    it('reminds the driver and the passengers once', async () => {
      const { trip, driver, riders } = await makeTrip('14 minutes', {
        preTripConfirmSentAt: '46 minutes',
      });
      await sql(
        `UPDATE bookings SET "preTripReminderSentAt" = now() - interval '46 minutes' WHERE "tripId" = $1`,
        [trip],
      );

      await reminders.sweep();

      expect(sentTo('presence_driver_prompt')).toContain(driver);
      expect(sentTo('trip_reminder')).toContain(riders[0]);

      notifications.create.mockClear();
      await reminders.sweep();
      expect(sentTo('trip_reminder')).not.toContain(riders[0]);
      expect(sentTo('presence_driver_prompt')).not.toContain(driver);
    });

    it('skips it when the hour reminder only just went out', async () => {
      const { driver, riders } = await makeTrip('10 minutes');

      await reminders.sweep();

      // The first reminder, sent now, and no second one on its heels.
      expect(sentTo('presence_prompt')).toContain(riders[0]);
      expect(
        sentTo('presence_driver_prompt').filter((d) => d === driver),
      ).toHaveLength(1);
      expect(sentTo('trip_reminder')).not.toContain(riders[0]);
    });
  });
});
