import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddExpiresAtToBookings1745930000000 implements MigrationInterface {
  name = 'AddExpiresAtToBookings1745930000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "expiresAt" TIMESTAMP NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" DROP COLUMN IF EXISTS "expiresAt"`,
    );
  }
}
