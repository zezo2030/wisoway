import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Stores the app language ("ar" | "en") the device last registered with, so
 * pushes rendered server-side (instant offers, iOS alerts) follow the app
 * language rather than the OS locale.
 */
export class AddDeviceTokenLocale1747600000000 implements MigrationInterface {
  name = 'AddDeviceTokenLocale1747600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "device_tokens" ADD COLUMN IF NOT EXISTS "locale" varchar(8)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "device_tokens" DROP COLUMN IF EXISTS "locale"`,
    );
  }
}
