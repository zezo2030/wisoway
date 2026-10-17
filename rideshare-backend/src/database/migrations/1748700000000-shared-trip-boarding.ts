import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Shared trips no longer start on the clock alone: at departure they wait for
 * a passenger to confirm they are in the car (or the driver to start them).
 * - `trips.boardingPromptSentAt`: the «هل أنت في السيارة؟» prompt went out.
 * - `bookings.preTripReminderSentAt`: the hour-before reminder reached this
 *   booking (it was once per trip, so later bookings never got it).
 */
export class SharedTripBoarding1748700000000 implements MigrationInterface {
  name = 'SharedTripBoarding1748700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "boardingPromptSentAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "preTripReminderSentAt" TIMESTAMPTZ NULL`,
    );
    // Bookings on trips already reminded count as reminded.
    await queryRunner.query(
      `UPDATE "bookings" b SET "preTripReminderSentAt" = t."preTripConfirmSentAt"
         FROM "trips" t
        WHERE t.id = b."tripId" AND t."preTripConfirmSentAt" IS NOT NULL
          AND b."preTripReminderSentAt" IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" DROP COLUMN IF EXISTS "preTripReminderSentAt"`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "boardingPromptSentAt"`,
    );
  }
}
