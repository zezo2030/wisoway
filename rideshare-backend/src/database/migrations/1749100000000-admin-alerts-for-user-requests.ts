import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Admins are alerted to every request waiting on them: wallet top-ups,
 * payouts, refund requests and complaints.
 */
export class AdminAlertsForUserRequests1749100000000 implements MigrationInterface {
  name = 'AdminAlertsForUserRequests1749100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    for (const value of [
      'wallet_topup',
      'payout_request',
      'refund_request',
      'complaint',
    ]) {
      await queryRunner.query(`
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1 FROM pg_type WHERE typname = 'admin_alert_preference_alerttype_enum'
          ) AND NOT EXISTS (
            SELECT 1
            FROM pg_enum e
            JOIN pg_type t ON e.enumtypid = t.oid
            WHERE t.typname = 'admin_alert_preference_alerttype_enum'
              AND e.enumlabel = '${value}'
          ) THEN
            ALTER TYPE "admin_alert_preference_alerttype_enum"
              ADD VALUE '${value}';
          END IF;
        END $$;
      `);
    }
  }

  public async down(): Promise<void> {
    // Postgres cannot easily remove enum values; leave them in place.
  }
}
