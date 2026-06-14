import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Adds admin-issued fine fields to pending_charges:
 *  - reason: free-text justification entered by the admin
 *  - createdByAdminId: admin user that issued the fine (null for legacy rows)
 */
export class AddAdminFieldsToPendingCharges1746000000000
  implements MigrationInterface
{
  name = 'AddAdminFieldsToPendingCharges1746000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "pending_charges"
      ADD COLUMN IF NOT EXISTS "reason" TEXT NULL,
      ADD COLUMN IF NOT EXISTS "createdByAdminId" UUID NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "pending_charges"
      DROP COLUMN IF EXISTS "createdByAdminId",
      DROP COLUMN IF EXISTS "reason"
    `);
  }
}
