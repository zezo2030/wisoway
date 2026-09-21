import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Adds insuranceImageUrl to the vehicles table. New driver registrations must
 * upload an insurance document, but the column stays nullable so vehicles that
 * registered before this step keep working until an admin asks for the file.
 */
export class AddInsuranceImageUrlToVehicles1746900000000 implements MigrationInterface {
  name = 'AddInsuranceImageUrlToVehicles1746900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "vehicles"
      ADD COLUMN IF NOT EXISTS "insuranceImageUrl" TEXT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "vehicles" DROP COLUMN IF EXISTS "insuranceImageUrl"
    `);
  }
}
