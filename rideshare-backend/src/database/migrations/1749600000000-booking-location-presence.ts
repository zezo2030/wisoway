import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Proof that a passenger travelled with the driver, for commission. Only the
 * running result is stored; the passenger's positions are not.
 */
export class BookingLocationPresence1749600000000 implements MigrationInterface {
  name = 'BookingLocationPresence1749600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ADD COLUMN IF NOT EXISTS "locationVerifiedAt" timestamptz,
        ADD COLUMN IF NOT EXISTS "locationMatchStartedAt" timestamptz,
        ADD COLUMN IF NOT EXISTS "locationMatchLat" double precision,
        ADD COLUMN IF NOT EXISTS "locationMatchLng" double precision,
        ADD COLUMN IF NOT EXISTS "locationMatchMeters" double precision NOT NULL DEFAULT 0
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        DROP COLUMN IF EXISTS "locationVerifiedAt",
        DROP COLUMN IF EXISTS "locationMatchStartedAt",
        DROP COLUMN IF EXISTS "locationMatchLat",
        DROP COLUMN IF EXISTS "locationMatchLng",
        DROP COLUMN IF EXISTS "locationMatchMeters"
    `);
  }
}
