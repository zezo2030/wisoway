/**
 * يمسح كل الرحلات والحجوزات والبيانات المرتبطة من PostgreSQL.
 * تشغيل: npx ts-node -r dotenv/config src/database/scripts/clear-trips-and-bookings.ts
 */
import 'reflect-metadata';
import { AppDataSource } from '../data-source';

async function main() {
  await AppDataSource.initialize();
  const q = AppDataSource.createQueryRunner();
  await q.connect();
  await q.startTransaction();
  try {
    await q.query(`UPDATE bookings SET "passengerPaymentId" = NULL`);
    await q.query(
      `DELETE FROM payments WHERE "tripId" IS NOT NULL OR "bookingId" IS NOT NULL`,
    );
    const hasRatings = await q.query(`
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'ratings'
    `);
    if (hasRatings.length > 0) {
      await q.query(`DELETE FROM ratings`);
    }
    await q.query(`DELETE FROM trips`);
    await q.commitTransaction();
    // eslint-disable-next-line no-console
    console.log(
      'Done: cleared trips (bookings, driver_locations, chat_rooms/messages cascade), trip-related payments, ratings.',
    );
  } catch (e) {
    await q.rollbackTransaction();
    throw e;
  } finally {
    await q.release();
    await AppDataSource.destroy();
  }
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
