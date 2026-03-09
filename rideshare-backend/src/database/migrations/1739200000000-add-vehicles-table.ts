import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddVehiclesTable1739200000000 implements MigrationInterface {
  name = 'AddVehiclesTable1739200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS vehicles (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "driverId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "vehicleType" VARCHAR NOT NULL,
        "plateNumber" VARCHAR(20) NOT NULL,
        model VARCHAR(100) NOT NULL,
        seats INT NOT NULL,
        "licenseImageUrl" TEXT,
        "vehicleLicenseImageUrl" TEXT,
        "isVerified" BOOLEAN NOT NULL DEFAULT FALSE,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT idx_vehicles_driver_id UNIQUE ("driverId")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS vehicles`);
  }
}
