import 'dotenv/config';
import * as path from 'path';
import { randomUUID } from 'crypto';
import Bull from 'bull';
import { DataSource } from 'typeorm';
import { TripEntity } from '../../src/database/entities/trip.entity';
import { TripLifecycleSweepJob } from '../../src/jobs/trip-lifecycle-sweep.job';

/**
 * Runs the sweep against the real schema and real Bull jobs. Needs the local
 * Postgres and Redis; the rows and the throwaway queues are removed afterwards.
 */
describe('TripLifecycleSweepJob — a trip past its time (real database, Redis)', () => {
  const database = new DataSource({
    type: 'postgres',
    host: process.env.POSTGRES_HOST,
    port: Number(process.env.POSTGRES_PORT),
    username: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB,
    entities: [path.join(__dirname, '../../src/database/entities/*.entity.ts')],
  });
  const redis = {
    host: process.env.REDIS_HOST,
    port: Number(process.env.REDIS_PORT),
  };
  const startQueue = new Bull(`test-auto-start-${randomUUID()}`, { redis });
  const completeQueue = new Bull(`test-auto-complete-${randomUUID()}`, {
    redis,
  });
  const drivers: string[] = [];
  let sweep: TripLifecycleSweepJob;

  const startedTrip = async (startedAgo: string): Promise<string> => {
    const driver = randomUUID();
    const trip = randomUUID();
    await database.query(
      `INSERT INTO users (id, "phoneNumber", name, email, role)
       VALUES ($1, $2, 'Test', $3, 'driver')`,
      [
        driver,
        `+9627${driver.replace(/\D/g, '').slice(0, 8)}`,
        `${driver}@example.com`,
      ],
    );
    drivers.push(driver);
    await database.query(
      `INSERT INTO trips (id, "driverId", "fromName", "toName", "fromPoint", "toPoint",
         "departureTime", "tripStartedAt", price, status)
       VALUES ($1, $2, 'A', 'B', ST_MakePoint(37.9, 26.65)::geography,
         ST_MakePoint(37.9, 26.668)::geography, now() - $3::interval,
         now() - $3::interval, 5, 'in_progress')`,
      [trip, driver, startedAgo],
    );
    return trip;
  };

  const scheduleForTomorrow = (tripId: string) =>
    completeQueue.add(
      'enforce',
      { tripId },
      { jobId: `trip-auto-complete-${tripId}`, delay: 24 * 60 * 60 * 1000 },
    );

  beforeAll(async () => {
    await database.initialize();
    sweep = new TripLifecycleSweepJob(
      database.getRepository(TripEntity),
      startQueue,
      completeQueue,
    );
  });

  afterAll(async () => {
    await database.query(`DELETE FROM trips WHERE "driverId" = ANY($1)`, [
      drivers,
    ]);
    await database.query(`DELETE FROM users WHERE id = ANY($1)`, [drivers]);
    await database.destroy();
    await startQueue.obliterate({ force: true });
    await completeQueue.obliterate({ force: true });
    await startQueue.close();
    await completeQueue.close();
  });

  it('brings forward the 24-hour job of a short trip that is overdue', async () => {
    const overdue = await startedTrip('40 minutes');
    const job = await scheduleForTomorrow(overdue);

    await sweep.sweep();

    await expect(job.getState()).resolves.toBe('waiting');
  });

  it('adds the job again when it was lost', async () => {
    const overdue = await startedTrip('40 minutes');

    await sweep.sweep();

    const job = await completeQueue.getJob(`trip-auto-complete-${overdue}`);
    await expect(job?.getState()).resolves.toBe('waiting');
  });

  it('leaves a trip that still has time', async () => {
    const recent = await startedTrip('10 minutes');
    const job = await scheduleForTomorrow(recent);

    await sweep.sweep();

    await expect(job.getState()).resolves.toBe('delayed');
  });
});
