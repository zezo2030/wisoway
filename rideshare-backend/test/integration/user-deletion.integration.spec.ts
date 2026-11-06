import { randomUUID } from 'crypto';
import 'dotenv/config';
import * as path from 'path';
import { DataSource } from 'typeorm';
import { AdminUserDeletionService } from '../../src/modules/admin/admin-user-deletion.service';
import {
  PRIVATE_DOCUMENT_PREFIX,
  PrivateDocumentsService,
} from '../../src/modules/uploads/private-documents.service';
import { UploadsService } from '../../src/modules/uploads/uploads.service';

/**
 * Runs against the real schema, because what decides whether a delete works is
 * the database's own foreign keys. Needs the local Postgres; every row is made
 * here and removed afterwards.
 */
describe('AdminUserDeletionService (real database)', () => {
  const removeDocument = jest.fn().mockResolvedValue(undefined);
  const deleteFile = jest.fn().mockResolvedValue({ message: 'File deleted' });
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
  let service: AdminUserDeletionService;

  const sql = (query: string, params: unknown[] = []) =>
    database.query(query, params);

  const makeUser = async (role = 'passenger'): Promise<string> => {
    const id = randomUUID();
    await sql(
      `INSERT INTO users (id, "phoneNumber", name, email, role, "photoUrl")
       VALUES ($1, $2, 'Test', $3, $4, 'https://x.test/uploads/profile/a.jpg')`,
      [id, `+9627${Date.now() % 100000000}`, `${id}@example.com`, role],
    );
    created.push(id);
    await new Promise((resolve) => setTimeout(resolve, 2));
    return id;
  };

  const makeTrip = async (driverId: string, status: string) => {
    const id = randomUUID();
    await sql(
      `INSERT INTO trips (id, "driverId", "fromName", "toName", "fromPoint", "toPoint",
         "departureTime", price, status)
       VALUES ($1, $2, 'A', 'B', ST_MakePoint(35, 31)::geography,
         ST_MakePoint(36, 32)::geography, now(), 5, $3)`,
      [id, driverId, status],
    );
    return id;
  };

  const makeBooking = async (
    tripId: string,
    userId: string,
    status: string,
  ) => {
    const id = randomUUID();
    await sql(
      `INSERT INTO bookings (id, "tripId", "userId", status, "totalAmount")
       VALUES ($1, $2, $3, $4, 5)`,
      [id, tripId, userId, status],
    );
    return id;
  };

  const count = async (query: string, id: string) =>
    Number((await sql(query, [id]))[0].n);

  beforeAll(async () => {
    await database.initialize();
    service = new AdminUserDeletionService(
      database,
      { remove: removeDocument } as unknown as PrivateDocumentsService,
      { deleteFile } as unknown as UploadsService,
    );
  });

  afterAll(async () => {
    await sql(`DELETE FROM messages WHERE "senderId" = ANY($1)`, [created]);
    await sql(`DELETE FROM payments WHERE "userId" = ANY($1)`, [created]);
    await sql(`DELETE FROM trips WHERE "driverId" = ANY($1)`, [created]);
    await sql(`DELETE FROM users WHERE id = ANY($1)`, [created]);
    await sql(
      `DELETE FROM security_events WHERE "eventType" = 'account_deleted'
         AND metadata->>'deletedUserId' = ANY($1)`,
      [created],
    );
    await database.destroy();
  });

  it('erases a driver with finished history and everything tied to it', async () => {
    const admin = await makeUser('admin');
    const driver = await makeUser('driver');
    const passenger = await makeUser();
    const trip = await makeTrip(driver, 'completed');
    await makeBooking(trip, passenger, 'completed');
    const room = randomUUID();
    await sql(`INSERT INTO chat_rooms (id, "tripId") VALUES ($1, $2)`, [
      room,
      trip,
    ]);
    await sql(
      `INSERT INTO messages ("chatRoomId", "senderId", text) VALUES ($1, $2, 'hi')`,
      [room, driver],
    );
    await sql(
      `INSERT INTO payments ("userId", amount, currency, method, status)
       VALUES ($1, 5, 'JOD', 'cliq', 'completed')`,
      [driver],
    );
    await sql(
      `INSERT INTO vehicles ("driverId", "vehicleType", "plateNumber", model, seats,
         "nationalIdImageUrl", "carImageUrl")
       VALUES ($1, 'sedan', 'T1', 'M', 4, $2, 'https://x.test/uploads/cars/c.jpg')`,
      [driver, `${PRIVATE_DOCUMENT_PREFIX}id.jpg`],
    );
    await sql(
      `INSERT INTO wallet_accounts ("userId", "accountType", balance) VALUES ($1, 'driver', 0)`,
      [driver],
    );

    const preview = await service.preview(driver);
    expect(preview.blockers).toEqual([]);
    expect(preview.counts).toMatchObject({
      trips: 1,
      otherPassengersBookings: 1,
      messages: 1,
      payments: 1,
    });

    await service.delete(driver, admin);

    const n = (table: string, column: string) =>
      count(`SELECT count(*) n FROM ${table} WHERE "${column}" = $1`, driver);
    expect(
      await count(`SELECT count(*) n FROM users WHERE id = $1`, driver),
    ).toBe(0);
    expect(await n('trips', 'driverId')).toBe(0);
    expect(await n('messages', 'senderId')).toBe(0);
    expect(await n('payments', 'userId')).toBe(0);
    expect(await n('vehicles', 'driverId')).toBe(0);
    expect(await n('wallet_accounts', 'userId')).toBe(0);
    expect(
      await count(`SELECT count(*) n FROM users WHERE id = $1`, passenger),
    ).toBe(1);
    expect(removeDocument).toHaveBeenCalledWith(
      `${PRIVATE_DOCUMENT_PREFIX}id.jpg`,
    );
    expect(deleteFile).toHaveBeenCalledWith('cars/c.jpg', 'admin');
    expect(deleteFile).toHaveBeenCalledWith('profile/a.jpg', 'admin');
    expect(
      await count(
        `SELECT count(*) n FROM security_events
         WHERE "eventType" = 'account_deleted' AND metadata->>'deletedUserId' = $1`,
        driver,
      ),
    ).toBe(1);
  });

  it('refuses while a passenger is waiting on the driver, and keeps the account', async () => {
    const driver = await makeUser('driver');
    const passenger = await makeUser();
    const trip = await makeTrip(driver, 'published');
    await makeBooking(trip, passenger, 'confirmed');

    await expect(service.delete(driver, driver)).rejects.toMatchObject({
      status: 409,
    });
    await expect(service.delete(passenger, driver)).rejects.toMatchObject({
      status: 409,
    });
    expect(
      await count(`SELECT count(*) n FROM users WHERE id = $1`, driver),
    ).toBe(1);
  });

  it('refuses while the wallet holds money', async () => {
    const user = await makeUser();
    await sql(
      `INSERT INTO wallet_accounts ("userId", "accountType", balance) VALUES ($1, 'rider', 12.5)`,
      [user],
    );

    expect((await service.preview(user)).blockers).toEqual([
      'WALLET_NOT_EMPTY',
    ]);
    await expect(service.delete(user, user)).rejects.toMatchObject({
      status: 409,
    });
  });

  it('refuses a fresh pending payment but not a long-abandoned one', async () => {
    const user = await makeUser();
    const payment = randomUUID();
    await sql(
      `INSERT INTO payments (id, "userId", amount, currency, method, status)
       VALUES ($1, $2, 5, 'JOD', 'cliq', 'pending')`,
      [payment, user],
    );
    expect((await service.preview(user)).blockers).toEqual(['RECENT_PAYMENT']);

    await sql(
      `UPDATE payments SET "createdAt" = now() - interval '2 hours' WHERE id = $1`,
      [payment],
    );
    expect((await service.preview(user)).blockers).toEqual([]);
  });

  it('never deletes an admin', async () => {
    const admin = await makeUser('admin');
    await expect(service.delete(admin, admin)).rejects.toMatchObject({
      status: 400,
    });
  });
});
