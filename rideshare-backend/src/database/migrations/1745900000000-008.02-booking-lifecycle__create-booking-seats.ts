import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T060 — Migration: create booking_seats table and backfill from bookings.seatNumber
 *
 * Phase 4 / 008-platform-completion / US2 / 010-booking-lifecycle
 *
 * - Creates `booking_seats` table with all columns from data-model.md
 * - Backfills one BookingSeat row per existing booking (isMainBooker=true,
 *   displayName=user.fullName, gender=user.gender)
 * - Drops the composite unique index idx_bookings_user_trip (seats now have
 *   their own uniqueness) — keeps bookings.seatNumber for one release as the
 *   v1-shim source
 * - Adds partial unique index: (bookingId) WHERE isMainBooker = true
 */
export class BookingLifecycle02CreateBookingSeats1745900000000 implements MigrationInterface {
  name = 'BookingLifecycle02CreateBookingSeats1745900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── 1. Create booking_seats ─────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "booking_seats" (
        "id"              UUID        NOT NULL DEFAULT gen_random_uuid(),
        "bookingId"       UUID        NOT NULL,
        "seatNumber"      VARCHAR(10) NOT NULL,
        "isMainBooker"    BOOLEAN     NOT NULL DEFAULT false,
        "displayName"     VARCHAR(100) NOT NULL DEFAULT '',
        "gender"          VARCHAR(10) NOT NULL DEFAULT '',
        "markedAbsentAt"  TIMESTAMP   NULL,
        "createdAt"       TIMESTAMP   NOT NULL DEFAULT now(),
        CONSTRAINT "PK_booking_seats" PRIMARY KEY ("id"),
        CONSTRAINT "FK_booking_seats_booking"
          FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE
      )
    `);

    // ── 2. Indexes ──────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE INDEX "idx_booking_seats_booking"
        ON "booking_seats" ("bookingId")
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX "idx_booking_seats_seat_number"
        ON "booking_seats" ("bookingId", "seatNumber")
    `);

    // Partial unique index: exactly one main booker per booking
    await queryRunner.query(`
      CREATE UNIQUE INDEX "idx_booking_seats_main_booker"
        ON "booking_seats" ("bookingId")
        WHERE "isMainBooker" = true
    `);

    // ── 3. Backfill from bookings.seatNumber ────────────────────────────────
    // For each existing booking, create one BookingSeat row.
    // Use user.fullName and user.gender from the users table.
    await queryRunner.query(`
      INSERT INTO "booking_seats"
        ("id", "bookingId", "seatNumber", "isMainBooker", "displayName", "gender", "createdAt")
      SELECT
        gen_random_uuid(),
        b."id",
        COALESCE(b."seatNumber", '0-0'),
        true,
        COALESCE(u."name", ''),
        COALESCE(u."gender", ''),
        b."createdAt"
      FROM "bookings" b
      LEFT JOIN "users" u ON u."id" = b."userId"
      WHERE b."seatNumber" IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM "booking_seats" bs WHERE bs."bookingId" = b."id"
        )
    `);

    // ── 4. Drop old composite unique index (seats now own uniqueness) ───────
    await queryRunner.query(`
      ALTER TABLE "bookings" DROP CONSTRAINT IF EXISTS "bookings_user_trip_unique"
    `);

    await queryRunner.query(`
      DROP INDEX IF EXISTS "idx_bookings_user_trip"
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings" ADD CONSTRAINT "bookings_user_trip_unique"
        UNIQUE ("userId", "tripId")
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "idx_bookings_user_trip"
        ON "bookings" ("userId", "tripId")
    `);

    await queryRunner.query(`DROP TABLE IF EXISTS "booking_seats"`);
  }
}
