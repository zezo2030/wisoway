import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * A matched driver who hasn't reached the passenger in time is reminded to
 * hurry. The count and first-warning time are kept per ride, so repeated
 * lateness over the last 30 days can be called out (and fined later).
 */
export class AddInstantLateWarnings1748300000000 implements MigrationInterface {
  name = 'AddInstantLateWarnings1748300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "lateWarningCount" INT NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "lateWarnedAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "instant_requests_driver_late_idx" ON "instant_ride_requests" ("matchedDriverId", "lateWarnedAt") WHERE "lateWarnedAt" IS NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "instant_requests_driver_late_idx"`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "lateWarnedAt"`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "lateWarningCount"`,
    );
  }
}
