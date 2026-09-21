import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSeatLayoutToVehicles1745920000000 implements MigrationInterface {
  name = 'AddSeatLayoutToVehicles1745920000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS "seatLayout" JSONB`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE vehicles DROP COLUMN IF EXISTS "seatLayout"`,
    );
  }
}
