import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * More reminders around a shared trip's time.
 * - `trips.soonReminderSentAt`: the 15-minutes-before reminder went out.
 * - `trips.boardingReminderSentAt`: the last «ابدأ الرحلة / هل أنت في
 *   السيارة؟» nudge while the trip waits after departure.
 */
export class TripReminders1749700000000 implements MigrationInterface {
  name = 'TripReminders1749700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "soonReminderSentAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "boardingReminderSentAt" TIMESTAMPTZ NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "boardingReminderSentAt"`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "soonReminderSentAt"`,
    );
  }
}
