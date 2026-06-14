import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T061 — Migration: add new booking fields for Phase 4
 *
 * Adds to `bookings`:
 *  - seatCount         (integer, default 1)
 *  - totalAmount       (decimal 10,2, nullable first cut)
 *  - settledAt         (timestamp, nullable)
 *  - settlementGraceUntil (timestamp, nullable)
 *  - passengerPresenceConfirmedAt (timestamp, nullable)
 *  - driverConfirmedPassengerAt   (timestamp, nullable)
 *  - driverMarkedAbsentAt         (timestamp, nullable)
 *
 * Phase 4 / 008-platform-completion / US2 / 010-booking-lifecycle
 */
export class BookingLifecycle03AddBookingFields1745901000000 implements MigrationInterface {
  name = 'BookingLifecycle03AddBookingFields1745901000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ADD COLUMN IF NOT EXISTS "seatCount"
          INTEGER NOT NULL DEFAULT 1,
        ADD COLUMN IF NOT EXISTS "totalAmount"
          DECIMAL(10,2) NULL,
        ADD COLUMN IF NOT EXISTS "settledAt"
          TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS "settlementGraceUntil"
          TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS "passengerPresenceConfirmedAt"
          TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS "driverConfirmedPassengerAt"
          TIMESTAMP NULL,
        ADD COLUMN IF NOT EXISTS "driverMarkedAbsentAt"
          TIMESTAMP NULL
    `);

    // Backfill totalAmount from seatPriceAtBooking for existing rows
    await queryRunner.query(`
      UPDATE "bookings"
        SET "totalAmount" = CAST("seatPriceAtBooking" AS DECIMAL(10,2))
      WHERE "seatPriceAtBooking" IS NOT NULL
        AND "totalAmount" IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        DROP COLUMN IF EXISTS "seatCount",
        DROP COLUMN IF EXISTS "totalAmount",
        DROP COLUMN IF EXISTS "settledAt",
        DROP COLUMN IF EXISTS "settlementGraceUntil",
        DROP COLUMN IF EXISTS "passengerPresenceConfirmedAt",
        DROP COLUMN IF EXISTS "driverConfirmedPassengerAt",
        DROP COLUMN IF EXISTS "driverMarkedAbsentAt"
    `);
  }
}
