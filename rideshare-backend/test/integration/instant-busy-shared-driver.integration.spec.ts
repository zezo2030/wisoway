import 'dotenv/config';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { DataSource } from 'typeorm';
import { DriverAvailabilityEntity } from '../../src/database/entities/driver-availability.entity';
import { DriverAvailabilityService } from '../../src/modules/instant-rides/driver-availability.service';

/**
 * Runs the instant-dispatch driver query against the real schema: a driver on
 * a shared trip gets no instant offers. Needs the local Postgres; every row is
 * made here, far from any real one, and removed afterwards.
 */
describe('findNearbyAvailableDrivers — a driver on a shared trip (real database)', () => {
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
  let service: DriverAvailabilityService;
  // Open sea, so no real driver is ever near.
  const lng = 3.123;
  const lat = 3.456;

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

  /** An online, funded driver waiting for instant offers right here. */
  const onlineDriver = async (): Promise<string> => {
    const driver = await makeUser('driver');
    await sql(
      `INSERT INTO wallet_accounts ("userId", "accountType", currency, balance)
       VALUES ($1, 'driver', 'JOD', 50)`,
      [driver],
    );
    await sql(
      `INSERT INTO driver_availability ("driverId", "isOnline", "acceptsInstant",
         point, "lastSeenAt")
       VALUES ($1, true, true, ST_MakePoint($2, $3)::geography, now())`,
      [driver, lng, lat],
    );
    return driver;
  };

  const sharedTrip = async (
    driver: string,
    status: string,
    departure: string,
    confirmedRider: boolean,
  ) => {
    const trip = randomUUID();
    await sql(
      `INSERT INTO trips (id, "driverId", "fromName", "toName", "fromPoint", "toPoint",
         "departureTime", price, status)
       VALUES ($1, $2, 'A', 'B', ST_MakePoint(35, 31)::geography,
         ST_MakePoint(36, 32)::geography, now() + $3::interval, 5, $4)`,
      [trip, driver, departure, status],
    );
    if (confirmedRider) {
      await sql(
        `INSERT INTO bookings ("tripId", "userId", status, "totalAmount")
         VALUES ($1, $2, 'confirmed', 5)`,
        [trip, await makeUser('passenger')],
      );
    }
  };

  const offered = async () =>
    (await service.findNearbyAvailableDrivers(lat, lng, 1000)).map(
      (d) => d.driverId,
    );

  beforeAll(async () => {
    await database.initialize();
    service = new DriverAvailabilityService(
      database.getRepository(DriverAvailabilityEntity),
      null as never,
      null as never,
      null as never,
    );
  });

  afterAll(async () => {
    await sql(`DELETE FROM driver_availability WHERE "driverId" = ANY($1)`, [
      users,
    ]);
    await sql(`DELETE FROM trips WHERE "driverId" = ANY($1)`, [users]);
    await sql(`DELETE FROM wallet_accounts WHERE "userId" = ANY($1)`, [users]);
    await sql(`DELETE FROM users WHERE id = ANY($1)`, [users]);
    await database.destroy();
  });

  it('skips a driver whose shared trip is under way, due or leaving soon', async () => {
    const free = await onlineDriver();
    const driving = await onlineDriver();
    await sharedTrip(driving, 'in_progress', '-20 minutes', true);
    const waiting = await onlineDriver();
    await sharedTrip(waiting, 'published', '-5 minutes', true);
    const leavingSoon = await onlineDriver();
    await sharedTrip(leavingSoon, 'fully_booked', '20 minutes', true);
    const laterToday = await onlineDriver();
    await sharedTrip(laterToday, 'published', '3 hours', true);
    const nobodyBooked = await onlineDriver();
    await sharedTrip(nobodyBooked, 'published', '10 minutes', false);

    const ids = await offered();

    expect(ids).toEqual(
      expect.arrayContaining([free, laterToday, nobodyBooked]),
    );
    expect(ids).not.toContain(driving);
    expect(ids).not.toContain(waiting);
    expect(ids).not.toContain(leavingSoon);
  });
});
