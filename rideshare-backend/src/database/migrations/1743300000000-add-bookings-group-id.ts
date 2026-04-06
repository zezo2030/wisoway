import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Adds a grouping key to tie multiple seat records
 * to one passenger booking action.
 */
export class AddBookingsGroupId1743300000000 implements MigrationInterface {
  name = 'AddBookingsGroupId1743300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE bookings
      ADD COLUMN IF NOT EXISTS "bookingGroupId" uuid NULL
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_bookings_group
      ON bookings ("bookingGroupId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_bookings_group`);
    await queryRunner.query(`
      ALTER TABLE bookings
      DROP COLUMN IF EXISTS "bookingGroupId"
    `);
  }
}
