import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddTripsMissingColumns1739100000000 implements MigrationInterface {
  name = 'AddTripsMissingColumns1739100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "driverName" VARCHAR;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "fromAddress" TEXT;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "toAddress" TEXT;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "seatLayout" JSONB;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "seats" JSONB DEFAULT '[]'::jsonb;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "communicationFeeStatus" VARCHAR DEFAULT 'not_paid';
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "carImageUrl" TEXT;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "driverWalletChargeApplied" BOOLEAN DEFAULT FALSE;
    `);
    await queryRunner.query(`
      ALTER TABLE trips ADD COLUMN IF NOT EXISTS "driverWalletChargeAt" TIMESTAMPTZ;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "driverName"`,
    );
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "fromAddress"`,
    );
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "toAddress"`,
    );
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "seatLayout"`,
    );
    await queryRunner.query(`ALTER TABLE trips DROP COLUMN IF EXISTS "seats"`);
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "communicationFeeStatus"`,
    );
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "carImageUrl"`,
    );
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "driverWalletChargeApplied"`,
    );
    await queryRunner.query(
      `ALTER TABLE trips DROP COLUMN IF EXISTS "driverWalletChargeAt"`,
    );
  }
}
