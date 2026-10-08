import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * The vehicle's colour, entered by the driver, so a passenger waiting for an
 * instant ride can pick the car out. Nullable: vehicles registered before this
 * have none until the driver adds it.
 */
export class AddVehicleColor1747900000000 implements MigrationInterface {
  name = 'AddVehicleColor1747900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "vehicles" ADD COLUMN IF NOT EXISTS "color" varchar(40)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "vehicles" DROP COLUMN IF EXISTS "color"`,
    );
  }
}
