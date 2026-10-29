import { MigrationInterface, QueryRunner } from 'typeorm';

export class DriverRevenueModel1748900000000 implements MigrationInterface {
  async up(q: QueryRunner): Promise<void> {
    await q.query(
      `ALTER TABLE wallet_accounts ALTER COLUMN "userId" DROP NOT NULL`,
    );
    await q.query(
      `ALTER TABLE wallet_accounts ADD COLUMN "rechargeRequired" boolean NOT NULL DEFAULT false`,
    );
    await q.query(
      `CREATE UNIQUE INDEX wallet_system_currency_unique ON wallet_accounts(currency) WHERE "accountType" = 'system' AND "userId" IS NULL`,
    );
    // Older payout requests did not reserve funds. Carry their obligations forward.
    await q.query(`UPDATE wallet_accounts w SET "reservedBalance"=w."reservedBalance"+p.amount
      FROM (SELECT "driverId", currency, SUM(amount) amount FROM payout_requests
        WHERE status IN ('pending','approved') GROUP BY "driverId", currency) p
      WHERE w."userId"=p."driverId" AND w.currency=p.currency AND w."accountType"='driver'`);
    // Historical completed trips keep their original accounting. No retroactive debit.
    await q.query(
      `INSERT INTO platform_settings(key, value) VALUES ('commission.cutover', now()::text) ON CONFLICT (key) DO NOTHING`,
    );
  }
  async down(): Promise<void> {
    throw new Error(
      'Revenue ledger migration cannot be reversed after posting system funds.',
    );
  }
}
