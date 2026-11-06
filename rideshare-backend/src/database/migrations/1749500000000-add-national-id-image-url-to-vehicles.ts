import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Adds nationalIdImageUrl to the vehicles table, next to the driving license.
 * New driver registrations must upload it; the column stays nullable so drivers
 * who registered before this step keep working.
 */
export class AddNationalIdImageUrlToVehicles1749500000000 implements MigrationInterface {
  name = 'AddNationalIdImageUrlToVehicles1749500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "vehicles"
      ADD COLUMN IF NOT EXISTS "nationalIdImageUrl" TEXT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "vehicles" DROP COLUMN IF EXISTS "nationalIdImageUrl"
    `);
  }
}
