import 'dotenv/config';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { DataSource } from 'typeorm';
import { InstantRidesService } from '../../src/modules/instant-rides/instant-rides.service';

/**
 * Runs the query that takes a passenger to their shared trip against the real
 * schema. Needs the local Postgres; every row is made here and removed.
 */
describe('getActiveRide — a due shared trip (real database)', () => {
  const database = new DataSource({
    type: 'postgres',
    host: process.env.POSTGRES_HOST,
    port: Number(process.env.POSTGRES_PORT),
    username: process.env.POSTGRES_USER,
    password: process.env.POSTGRES_PASSWORD,
    database: process.env.POSTGRES_DB,
    entities: [path.join(__dirname, '../../src/database/entities/*.entity.ts')],
  });
  const created: string[] = [];
  let service: InstantRidesService;

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
    created.push(id);
    return id;
  };

  const makeBooking = async (
    status: string,
    departure: string,
    seatStatus: string | null,
  ) => {
    const driver = await makeUser('driver');
    const passenger = await makeUser('passenger');
    const trip = randomUUID();
    const booking = randomUUID();
    await sql(
      `INSERT INTO trips (id, "driverId", "fromName", "toName", "fromPoint", "toPoint",
         "departureTime", price, status)
       VALUES ($1, $2, 'A', 'B', ST_MakePoint(35, 31)::geography,
         ST_MakePoint(36, 32)::geography, now() + $3::interval, 5, $4)`,
      [trip, driver, departure, status],
    );
    await sql(
      `INSERT INTO bookings (id, "tripId", "userId", status, "totalAmount")
       VALUES ($1, $2, $3, 'confirmed', 5)`,
      [booking, trip, passenger],
    );
    await sql(
      `INSERT INTO booking_seats ("bookingId", "seatNumber", "passengerDeclaredStatus")
       VALUES ($1, '1A', $2)`,
      [booking, seatStatus],
    );
    return { trip, passenger };
  };

  const activeTrip = async (userId: string) =>
    (await service.getActiveRide(userId))?.tripId ?? null;

  beforeAll(async () => {
    await database.initialize();
    service = new (InstantRidesService as any)();
    Object.assign(service, {
      tripRepo: database.getRepository('TripEntity'),
      requestRepo: database.getRepository('InstantRideRequestEntity'),
    });
  });

  afterAll(async () => {
    await sql(`DELETE FROM trips WHERE "driverId" = ANY($1)`, [created]);
    await sql(`DELETE FROM users WHERE id = ANY($1)`, [created]);
    await database.destroy();
  });

  it('takes the passenger to a trip under way', async () => {
    const { trip, passenger } = await makeBooking(
      'in_progress',
      '-1 hour',
      null,
    );
    expect(await activeTrip(passenger)).toBe(trip);
  });

  it('takes them to a trip whose time has come', async () => {
    const { trip, passenger } = await makeBooking(
      'published',
      '-1 minute',
      null,
    );
    expect(await activeTrip(passenger)).toBe(trip);
  });

  it('leaves them alone before departure', async () => {
    const { passenger } = await makeBooking('published', '1 hour', null);
    expect(await activeTrip(passenger)).toBeNull();
  });

  it('lets them go after saying they are not riding', async () => {
    const { passenger } = await makeBooking(
      'in_progress',
      '-1 hour',
      'not_riding',
    );
    expect(await activeTrip(passenger)).toBeNull();
  });

  it('stops holding them on a trip nobody started hours ago', async () => {
    const { passenger } = await makeBooking('published', '-7 hours', null);
    expect(await activeTrip(passenger)).toBeNull();
  });
});
