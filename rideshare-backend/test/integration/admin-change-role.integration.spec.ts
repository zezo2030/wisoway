import 'dotenv/config';
import * as path from 'path';
import { randomUUID } from 'crypto';
import { DataSource } from 'typeorm';
import { ConflictException, BadRequestException } from '@nestjs/common';
import { AdminDashboardService } from '../../src/modules/admin/admin-dashboard.service';

/**
 * The users page's role menu (PATCH /admin/users/:id/role) against the real
 * schema. Needs the local Postgres; every row is made here and removed.
 */
describe('Admin: change a user role (real database)', () => {
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
  const notifications = {
    create: jest.fn(async () => ({})),
    getPreferredLocale: jest.fn(async () => 'ar'),
  };
  let service: AdminDashboardService;

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

  const makeTrip = async (driver: string, status: string) => {
    const id = randomUUID();
    await sql(
      `INSERT INTO trips (id, "driverId", "fromName", "toName", "fromPoint", "toPoint",
         "departureTime", price, status)
       VALUES ($1, $2, 'A', 'B', ST_MakePoint(35, 31)::geography,
         ST_MakePoint(36, 32)::geography, now() + interval '1 day', 5, $3)`,
      [id, driver, status],
    );
    return id;
  };

  const book = async (trip: string, passenger: string, status: string) =>
    sql(
      `INSERT INTO bookings (id, "tripId", "userId", status, "totalAmount")
       VALUES ($1, $2, $3, $4, 5)`,
      [randomUUID(), trip, passenger, status],
    );

  const roleOf = async (id: string) =>
    (await sql(`SELECT role FROM users WHERE id = $1`, [id]))[0].role;
  const statusOf = async (trip: string) =>
    (await sql(`SELECT status FROM trips WHERE id = $1`, [trip]))[0].status;

  beforeAll(async () => {
    await database.initialize();
    service = new AdminDashboardService(
      database.getRepository('UserEntity') as never,
      database.getRepository('TripEntity') as never,
      ...Array(4).fill(null),
      database.getRepository('BookingEntity') as never,
      ...Array(5).fill(null),
      notifications as never,
      null as never,
      null as never,
    );
  });

  afterAll(async () => {
    await sql(
      `DELETE FROM bookings WHERE "userId" = ANY($1)
         OR "tripId" IN (SELECT id FROM trips WHERE "driverId" = ANY($1))`,
      [created],
    );
    await sql(`DELETE FROM trips WHERE "driverId" = ANY($1)`, [created]);
    await sql(`DELETE FROM notifications WHERE "userId" = ANY($1)`, [created]);
    await sql(`DELETE FROM users WHERE id = ANY($1)`, [created]);
    await database.destroy();
  });

  it('makes a driver a passenger, withdrawing the trips nobody booked', async () => {
    const admin = await makeUser('admin');
    const driver = await makeUser('driver');
    const open = await makeTrip(driver, 'published');
    const done = await makeTrip(driver, 'completed');

    await service.changeUserRole(driver, 'passenger' as never, admin);

    expect(await roleOf(driver)).toBe('passenger');
    expect(await statusOf(open)).toBe('cancelled');
    expect(await statusOf(done)).toBe('completed');
    expect(notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: driver, type: 'role_changed' }),
    );
  });

  it('makes a passenger a driver', async () => {
    const admin = await makeUser('admin');
    const passenger = await makeUser('passenger');

    await service.changeUserRole(passenger, 'driver' as never, admin);

    expect(await roleOf(passenger)).toBe('driver');
  });

  it('refuses while the driver has passengers booked', async () => {
    const admin = await makeUser('admin');
    const driver = await makeUser('driver');
    const trip = await makeTrip(driver, 'published');
    await book(trip, await makeUser('passenger'), 'confirmed');

    await expect(
      service.changeUserRole(driver, 'passenger' as never, admin),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(await roleOf(driver)).toBe('driver');
    expect(await statusOf(trip)).toBe('published');
  });

  it('refuses while the driver has a trip under way', async () => {
    const admin = await makeUser('admin');
    const driver = await makeUser('driver');
    await makeTrip(driver, 'in_progress');

    await expect(
      service.changeUserRole(driver, 'passenger' as never, admin),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('refuses while a passenger has a booking open', async () => {
    const admin = await makeUser('admin');
    const passenger = await makeUser('passenger');
    const trip = await makeTrip(await makeUser('driver'), 'published');
    await book(trip, passenger, 'pending');

    await expect(
      service.changeUserRole(passenger, 'driver' as never, admin),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it("won't let an admin change their own role", async () => {
    const admin = await makeUser('admin');

    await expect(
      service.changeUserRole(admin, 'passenger' as never, admin),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
