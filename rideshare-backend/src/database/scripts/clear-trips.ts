import 'reflect-metadata';
import 'dotenv/config';
import { AppDataSource } from '../data-source';

const CLEAR_ORDER = [
  'settlement_audits',
  'call_sessions',
  'refund_requests',
  'complaints',
  'trip_share_links',
  'trip_recurrence_rules',
  'pending_charges',
  'booking_seats',
  'wallet_holds',
  'payments',
  'bookings',
  'ratings',
  'messages',
  'chat_rooms',
  'trips',
];

async function run() {
  await AppDataSource.initialize();
  try {
    await AppDataSource.query('BEGIN');

    const tablesInDb = await AppDataSource.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
    );
    const existing = tablesInDb.map((t: any) => t.table_name);
    const toClear = CLEAR_ORDER.filter((t) => existing.includes(t));

    if (toClear.length === 0) {
      console.log('No trip-related tables found.');
    } else {
      const tableList = toClear.map((t) => '"' + t + '"').join(', ');
      await AppDataSource.query(
        'TRUNCATE TABLE ' + tableList + ' RESTART IDENTITY CASCADE',
      );
      console.log('Cleared:', toClear.join(', '));
    }

    await AppDataSource.query('COMMIT');
  } catch (e) {
    await AppDataSource.query('ROLLBACK');
    throw e;
  } finally {
    await AppDataSource.destroy();
  }
}

run().catch((e) => {
  console.error('Failed to clear trips:', e);
  process.exit(1);
});
