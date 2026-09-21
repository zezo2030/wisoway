import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * create-trip wizard — family booking exception.
 *
 * A passenger booking 2+ seats may flag the request as a *family booking*.
 * Family bookings are exempt from the trip-level `preventGenderMixing`
 * / gender-adjacency rules, so the flag has to survive on the booking row for
 * auditing and for any later re-validation of the seat map.
 *
 * The column is NOT NULL with a `false` default, so existing rows keep the
 * current (non-family) behaviour and the migration is safe to deploy ahead of
 * the application code.
 */
export class AddIsFamilyBookingToBookings1746800000000 implements MigrationInterface {
  name = 'AddIsFamilyBookingToBookings1746800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        ADD COLUMN IF NOT EXISTS "isFamilyBooking" BOOLEAN NOT NULL DEFAULT false
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings"
        DROP COLUMN IF EXISTS "isFamilyBooking"
    `);
  }
}
