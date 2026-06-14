import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T062 — Migration: convert bookings.status to a typed enum
 *
 * Extends the string column to a PostgreSQL enum with values:
 *   pending | confirmed | cancelled | rejected | in_progress | completed | no_show
 *
 * Backfills: existing string values map 1-1 (they already match the enum members).
 *
 * Phase 4 / 008-platform-completion / US2 / 010-booking-lifecycle
 */
export class BookingLifecycle04BookingStatusEnum1745902000000 implements MigrationInterface {
  name = 'BookingLifecycle04BookingStatusEnum1745902000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create the enum type
    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_type WHERE typname = 'booking_status_enum'
        ) THEN
          CREATE TYPE "booking_status_enum" AS ENUM (
            'pending',
            'confirmed',
            'cancelled',
            'rejected',
            'in_progress',
            'completed',
            'no_show'
          );
        END IF;
      END$$
    `);

    // 2. Add a temporary column using the enum type
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ADD COLUMN "status_enum" "booking_status_enum"
    `);

    // 3. Backfill: cast existing varchar values to the enum
    await queryRunner.query(`
      UPDATE "bookings"
        SET "status_enum" = "status"::"booking_status_enum"
      WHERE "status" IN (
        'pending','confirmed','cancelled','rejected','in_progress','completed','no_show'
      )
    `);

    // 4. Default any unrecognised values to 'cancelled' (safety net)
    await queryRunner.query(`
      UPDATE "bookings"
        SET "status_enum" = 'cancelled'
      WHERE "status_enum" IS NULL
    `);

    // 5. Set NOT NULL on the enum column
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ALTER COLUMN "status_enum" SET NOT NULL
    `);

    // 6. Drop the old varchar column and rename
    await queryRunner.query(`
      ALTER TABLE "bookings" DROP COLUMN "status"
    `);
    await queryRunner.query(`
      ALTER TABLE "bookings" RENAME COLUMN "status_enum" TO "status"
    `);

    // 7. Recreate the status index on the new column
    await queryRunner.query(`
      DROP INDEX IF EXISTS "idx_bookings_status"
    `);
    await queryRunner.query(`
      CREATE INDEX "idx_bookings_status" ON "bookings" ("status")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Reverse: convert back to varchar
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ADD COLUMN "status_varchar" VARCHAR NOT NULL DEFAULT 'pending'
    `);

    await queryRunner.query(`
      UPDATE "bookings" SET "status_varchar" = "status"::text
    `);

    await queryRunner.query(`ALTER TABLE "bookings" DROP COLUMN "status"`);

    await queryRunner.query(`
      ALTER TABLE "bookings" RENAME COLUMN "status_varchar" TO "status"
    `);

    await queryRunner.query(`DROP TYPE IF EXISTS "booking_status_enum"`);
  }
}
