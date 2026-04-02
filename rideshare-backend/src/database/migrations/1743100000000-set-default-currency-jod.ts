import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Product default region: Jordan (JOD). Updates DB column defaults for new rows.
 * Does not alter existing stored currency values.
 */
export class SetDefaultCurrencyJod1743100000000 implements MigrationInterface {
  name = 'SetDefaultCurrencyJod1743100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "payments" ALTER COLUMN "currency" SET DEFAULT 'JOD'`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "walletCurrency" SET DEFAULT 'JOD'`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ALTER COLUMN "currency" SET DEFAULT 'JOD'`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_accounts" ALTER COLUMN "currency" SET DEFAULT 'JOD'`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" ALTER COLUMN "currency" SET DEFAULT 'JOD'`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_holds" ALTER COLUMN "currency" SET DEFAULT 'JOD'`,
    );
    await queryRunner.query(
      `ALTER TABLE "payout_requests" ALTER COLUMN "currency" SET DEFAULT 'JOD'`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "payments" ALTER COLUMN "currency" SET DEFAULT 'EGP'`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ALTER COLUMN "walletCurrency" SET DEFAULT 'EGP'`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ALTER COLUMN "currency" SET DEFAULT 'EGP'`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_accounts" ALTER COLUMN "currency" SET DEFAULT 'EGP'`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_transactions" ALTER COLUMN "currency" SET DEFAULT 'EGP'`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_holds" ALTER COLUMN "currency" SET DEFAULT 'EGP'`,
    );
    await queryRunner.query(
      `ALTER TABLE "payout_requests" ALTER COLUMN "currency" SET DEFAULT 'EGP'`,
    );
  }
}
