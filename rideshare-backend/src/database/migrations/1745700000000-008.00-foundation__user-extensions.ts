import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 008.00 — Foundation: User Extensions
 *
 * Adds six columns to the `users` table required by ≥2 user stories in the
 * platform-completion feature.  All columns are additive (nullable or with a
 * safe default) so this migration can run on a live database without downtime.
 *
 * Backfill rules:
 *  - `restricted`       → false for all existing rows (default covers new rows).
 *  - `hidePhoneNumber`  → false for all existing rows (default covers new rows).
 *  - `pendingPhoneLink` → true for users that have a non-null social-login
 *                         `provider` value other than 'email' / 'phone' and no
 *                         `phoneNumber` yet (legacy OAuth accounts that have
 *                         not linked a phone number).
 *
 * `bannedAt`, `banReason`, `lastSocialLoginAt` start NULL for all existing rows.
 */
export class Foundation00UserExtensions1745700000000 implements MigrationInterface {
  name = 'Foundation00UserExtensions1745700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. bannedAt — timestamp when the admin banned this account
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "bannedAt" TIMESTAMPTZ NULL DEFAULT NULL
    `);

    // 2. banReason — human-readable reason shown on the ban screen
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "banReason" TEXT NULL DEFAULT NULL
    `);

    // 3. restricted — write-operations blocked; cleared by admin
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "restricted" BOOLEAN NOT NULL DEFAULT false
    `);

    // 4. hidePhoneNumber — route calls through Twilio proxy
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "hidePhoneNumber" BOOLEAN NOT NULL DEFAULT false
    `);

    // 5. pendingPhoneLink — legacy social-login accounts awaiting phone link
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "pendingPhoneLink" BOOLEAN NOT NULL DEFAULT false
    `);

    // 6. lastSocialLoginAt — last time the user authenticated via a social provider
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "lastSocialLoginAt" TIMESTAMPTZ NULL DEFAULT NULL
    `);

    // Backfill: mark legacy social-only accounts (provider not 'email'/'phone'
    // and no phoneNumber) as pending phone link so they are prompted to link.
    await queryRunner.query(`
      UPDATE users
        SET "pendingPhoneLink" = true
      WHERE "provider" NOT IN ('email', 'phone')
        AND ("phoneNumber" IS NULL OR "phoneNumber" = '')
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS "lastSocialLoginAt"`,
    );
    await queryRunner.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS "pendingPhoneLink"`,
    );
    await queryRunner.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS "hidePhoneNumber"`,
    );
    await queryRunner.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS "restricted"`,
    );
    await queryRunner.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS "banReason"`,
    );
    await queryRunner.query(
      `ALTER TABLE users DROP COLUMN IF EXISTS "bannedAt"`,
    );
  }
}
