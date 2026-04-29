import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T182 — Migration: 008.12-cleanup__bookings-total-amount-not-null
 *
 * Tightens `bookings.totalAmount` from nullable to NOT NULL.
 *
 * Background:
 *  - The column was created nullable in migration 008.01 to allow legacy
 *    rows that pre-dated the multi-seat pricing model to co-exist.
 *  - A backfill was run in migration 008.03 / Phase 4 (T061) to populate
 *    `totalAmount` for all existing rows using `seatCount × seatPriceAtBooking`.
 *  - Since Phase 4, every new booking sets `totalAmount` synchronously at
 *    creation time; no application path leaves it NULL.
 *  - Phase 9 / T182 promotes the column to NOT NULL as a schema-level contract.
 *
 * Safety pre-check: the migration first asserts that no NULL rows exist.
 * If any are found it raises an exception (should never happen in a healthy
 * deployment; use the admin backfill runbook if you hit this).
 */
export class CleanupBookingsTotalAmountNotNull1745912000000 implements MigrationInterface {
  name = 'CleanupBookingsTotalAmountNotNull1745912000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Safety guard: refuse to run if any NULL rows are still present.
    const [{ count }] = await queryRunner.query(`
      SELECT COUNT(*) AS count
        FROM "bookings"
       WHERE "totalAmount" IS NULL
    `);
    if (parseInt(count, 10) > 0) {
      throw new Error(
        `Migration 008.12 aborted: ${count} booking row(s) still have NULL totalAmount. ` +
          'Run the Phase 4 backfill script before re-running this migration.',
      );
    }

    await queryRunner.query(`
      ALTER TABLE "bookings"
        ALTER COLUMN "totalAmount" SET NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ALTER COLUMN "totalAmount" DROP NOT NULL
    `);
  }
}
