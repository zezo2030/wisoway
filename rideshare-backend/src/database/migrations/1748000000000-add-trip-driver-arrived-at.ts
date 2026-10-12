import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Instant rides now go heading-to-pickup → arrived → started → completed.
 * `driverArrivedAt` marks the driver reaching the passenger; `tripStartedAt`
 * (already present) is set only when the driver presses «بدء الرحلة» rather
 * than at match time.
 */
export class AddTripDriverArrivedAt1748000000000 implements MigrationInterface {
  name = 'AddTripDriverArrivedAt1748000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "driverArrivedAt" TIMESTAMPTZ NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "driverArrivedAt"`,
    );
  }
}
