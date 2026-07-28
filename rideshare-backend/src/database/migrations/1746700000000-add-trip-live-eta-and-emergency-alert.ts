import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTripLiveEtaAndEmergencyAlert1746700000000
  implements MigrationInterface
{
  name = 'AddTripLiveEtaAndEmergencyAlert1746700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD COLUMN IF NOT EXISTS "remainingDistanceKm" double precision,
        ADD COLUMN IF NOT EXISTS "remainingDurationSeconds" integer,
        ADD COLUMN IF NOT EXISTS "etaAt" TIMESTAMP WITH TIME ZONE,
        ADD COLUMN IF NOT EXISTS "routeProgressPercent" double precision,
        ADD COLUMN IF NOT EXISTS "etaComputedAt" TIMESTAMP WITH TIME ZONE
    `);

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
            AND e.enumlabel = 'trip_emergency'
        ) THEN
          ALTER TYPE "admin_alert_preference_alerttype_enum"
            ADD VALUE 'trip_emergency';
        END IF;
      END $$;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "trips"
        DROP COLUMN IF EXISTS "remainingDistanceKm",
        DROP COLUMN IF EXISTS "remainingDurationSeconds",
        DROP COLUMN IF EXISTS "etaAt",
        DROP COLUMN IF EXISTS "routeProgressPercent",
        DROP COLUMN IF EXISTS "etaComputedAt"
    `);
    // Postgres cannot easily remove enum values; leave trip_emergency in place.
  }
}
