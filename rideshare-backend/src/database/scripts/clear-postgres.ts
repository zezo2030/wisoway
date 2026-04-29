import 'reflect-metadata';
import 'dotenv/config';
import { AppDataSource } from '../data-source';

const CLEAR_ORDER = [
  // ── 008-platform-completion new tables (must precede their FK parents) ──────
  'settlement_audits',
  'call_sessions',
  'refund_requests',
  'complaints',
  'trip_share_links',
  'trip_recurrence_rules',
  'pending_charges',
  'booking_seats',
  'security_events',
  'account_flags',
  'user_devices',
  // ── Existing tables ──────────────────────────────────────────────────────────
  'wallet_holds',
  'wallet_transactions',
  'payout_requests',
  'payments',
  'bookings',
  'ratings',
  'messages',
  'chat_rooms',
  'notifications',
  'device_tokens',
  'driver_locations',
  'trips',
  'vehicles',
  'wallet_accounts',
  'communication_fees',
  'password_reset_sessions',
  'otp_codes',
  'pending_registrations',
  'users',
];

async function run() {
  await AppDataSource.initialize();

  try {
    await AppDataSource.query('BEGIN');

    // Check which tables exist before trying to truncate
    const tablesInDb = await AppDataSource.query(
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
    );
    const existingTables = tablesInDb.map((t: any) => t.table_name);
    const tablesToClear = CLEAR_ORDER.filter((table) =>
      existingTables.includes(table),
    );

    if (tablesToClear.length > 0) {
      const tableList = tablesToClear
        .map((table) => '"' + table + '"')
        .join(', ');
      await AppDataSource.query(
        'TRUNCATE TABLE ' + tableList + ' RESTART IDENTITY CASCADE',
      );
      console.log('Postgres database cleared successfully.');
    } else {
      console.log('No tables found to clear.');
    }

    await AppDataSource.query('COMMIT');
  } catch (error) {
    await AppDataSource.query('ROLLBACK');
    throw error;
  } finally {
    await AppDataSource.destroy();
  }
}

run().catch((error) => {
  console.error('Failed to clear Postgres database', error);
  process.exit(1);
});
