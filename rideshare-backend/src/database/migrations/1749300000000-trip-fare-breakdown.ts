import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Instant rides keep how their metered fare was reached (distance driven,
 * time, waiting, minimum), so the ride summary can show it.
 */
export class TripFareBreakdown1749300000000 implements MigrationInterface {
  name = 'TripFareBreakdown1749300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE trips ADD COLUMN IF NOT EXISTS "fareBreakdown" jsonb`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "fareBreakdown"`,
    );
  }
}
