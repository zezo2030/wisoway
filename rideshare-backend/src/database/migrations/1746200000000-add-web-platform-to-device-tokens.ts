import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddWebPlatformToDeviceTokens1746200000000 implements MigrationInterface {
  name = 'AddWebPlatformToDeviceTokens1746200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "device_tokens"
      ADD COLUMN IF NOT EXISTS "userAgent" VARCHAR(255) NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "device_tokens"
      DROP COLUMN IF EXISTS "userAgent"
    `);
  }
}
