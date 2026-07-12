import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Adds carImageUrl to the vehicles table. The car photo is captured once at
 * driver/vehicle registration (mandatory) and then surfaced on every trip
 * detail page. The trips table already carries its own carImageUrl, populated
 * at trip creation from this column.
 */
export class AddCarImageUrlToVehicles1746100000000 implements MigrationInterface {
  name = 'AddCarImageUrlToVehicles1746100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "vehicles"
      ADD COLUMN IF NOT EXISTS "carImageUrl" TEXT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "vehicles" DROP COLUMN IF EXISTS "carImageUrl"
    `);
  }
}
