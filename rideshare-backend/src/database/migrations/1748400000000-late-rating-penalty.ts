import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Lateness lowers a driver's rating instead of fining them:
 * - `platform_settings` holds dashboard-editable knobs, starting with the
 *   per-late-ride rating cut;
 * - `users.ratingPenaltyFactor` scales the average of received ratings;
 * - `instant_ride_requests.ratingPenaltyPercent` records the cut a ride cost.
 */
export class LateRatingPenalty1748400000000 implements MigrationInterface {
  name = 'LateRatingPenalty1748400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE TABLE IF NOT EXISTS "platform_settings" (
        "key" VARCHAR(64) PRIMARY KEY,
        "value" TEXT NOT NULL,
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now()
      )`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "ratingPenaltyFactor" DECIMAL(6,4) NOT NULL DEFAULT 1`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "ratingPenaltyPercent" DECIMAL(5,2) NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "ratingPenaltyPercent"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "ratingPenaltyFactor"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "platform_settings"`);
  }
}
