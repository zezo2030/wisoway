import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTripTypeToTrips1746310000000 implements MigrationInterface {
  name = 'AddTripTypeToTrips1746310000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "trips"
      ADD COLUMN IF NOT EXISTS "tripType" varchar(16) NOT NULL DEFAULT 'scheduled'
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "trips_trip_type_idx" ON "trips" ("tripType")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "trips_trip_type_idx"`);
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "tripType"`,
    );
  }
}
