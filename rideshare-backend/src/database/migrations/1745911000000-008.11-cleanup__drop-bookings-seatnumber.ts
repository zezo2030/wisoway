import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T181 — Migration: 008.11-cleanup__drop-bookings-seatnumber
 *
 * Drops the legacy `seatNumber` column from `bookings`.
 *
 * Background:
 *  - `seatNumber` was a v1 single-seat identifier kept for one release cycle
 *    as the v1-shim source (Phase 4 / R-007).
 *  - The multi-seat model (`BookingSeat` child rows) has been live since
 *    migration 008.02.  All bookings created since Phase 4 store their seat
 *    identity in `booking_seats` — `seatNumber` is no longer written or read
 *    by any application code as of Phase 9.
 *
 * Phase 9 / T181 — 008-platform-completion.
 */
export class CleanupDropBookingsSeatnumber1745911000000 implements MigrationInterface {
  name = 'CleanupDropBookingsSeatnumber1745911000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings" DROP COLUMN IF EXISTS "seatNumber"
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ADD COLUMN IF NOT EXISTS "seatNumber" varchar DEFAULT NULL
    `);
  }
}
