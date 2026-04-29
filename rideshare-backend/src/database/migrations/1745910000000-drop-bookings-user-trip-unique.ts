import { MigrationInterface, QueryRunner } from 'typeorm';

export class DropBookingsUserTripUnique1745910000000
  implements MigrationInterface
{
  name = 'DropBookingsUserTripUnique1745910000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings" DROP CONSTRAINT IF EXISTS "bookings_user_trip_unique"
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS "idx_bookings_user_trip"
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "bookings" ADD CONSTRAINT "bookings_user_trip_unique"
        UNIQUE ("userId", "tripId")
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "idx_bookings_user_trip"
        ON "bookings" ("userId", "tripId")
    `);
  }
}
