import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * inDrive-style continuous search + raise-fare nudge + matched ETA:
 * - requests: fareRevision (re-qualifies decliners after a raise), nudgedAt
 *   (full sweep found nobody → "raise your fare"), pickupEtaSeconds (driver→
 *   pickup estimate stored at match).
 * - offers: fareRevision the offer was made at.
 */
export class AddInstantDispatchWaves1746510000000 implements MigrationInterface {
  name = 'AddInstantDispatchWaves1746510000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      ADD COLUMN IF NOT EXISTS "fareRevision" integer NOT NULL DEFAULT 1,
      ADD COLUMN IF NOT EXISTS "nudgedAt" timestamptz,
      ADD COLUMN IF NOT EXISTS "pickupEtaSeconds" integer
    `);
    await queryRunner.query(`
      ALTER TABLE "instant_ride_offers"
      ADD COLUMN IF NOT EXISTS "fareRevision" integer NOT NULL DEFAULT 1
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "instant_ride_offers" DROP COLUMN IF EXISTS "fareRevision"
    `);
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      DROP COLUMN IF EXISTS "fareRevision",
      DROP COLUMN IF EXISTS "nudgedAt",
      DROP COLUMN IF EXISTS "pickupEtaSeconds"
    `);
  }
}
