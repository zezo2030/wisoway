import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Allows multiple bookings per (userId, tripId) for different seats.
 * Replaces UNIQUE(userId, tripId) with a non-unique index for lookups.
 */
export class DropBookingsUserTripUnique1743200000000
  implements MigrationInterface
{
  name = 'DropBookingsUserTripUnique1743200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_user_trip_unique`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS idx_bookings_user_trip`);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_bookings_user_trip ON bookings ("userId", "tripId")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_bookings_user_trip`);
    await queryRunner.query(`
      ALTER TABLE bookings ADD CONSTRAINT bookings_user_trip_unique UNIQUE ("userId", "tripId")
    `);
  }
}
