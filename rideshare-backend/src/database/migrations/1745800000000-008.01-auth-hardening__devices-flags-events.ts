import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 008.01 — Auth Hardening: user_devices, account_flags, security_events
 *
 * Creates three new tables required by Phase 3 (US1 — phone-only auth +
 * device binding + account-safety guardrails).
 *
 * All tables are additive; existing rows in `users` are unaffected.
 *
 * Tables:
 *  1. user_devices    — device sessions bound to a user after OTP (T021)
 *  2. account_flags   — risk/safety flags raised automatically or by admins (T022)
 *  3. security_events — append-only audit log of security-relevant actions (T023)
 */
export class AuthHardening01DevicesFlagsEvents1745800000000 implements MigrationInterface {
  name = 'AuthHardening01DevicesFlagsEvents1745800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── 1. user_devices ──────────────────────────────────────────────────────

    await queryRunner.query(`
      CREATE TYPE "user_device_status_enum" AS ENUM ('active', 'revoked')
    `);

    await queryRunner.query(`
      CREATE TYPE "user_device_platform_enum" AS ENUM ('android', 'ios')
    `);

    await queryRunner.query(`
      CREATE TABLE "user_devices" (
        "id"              UUID            NOT NULL DEFAULT gen_random_uuid(),
        "userId"          UUID            NOT NULL,
        "fingerprintHash" CHAR(64)        NOT NULL,
        "platform"        "user_device_platform_enum" NOT NULL,
        "label"           VARCHAR(120)    NULL DEFAULT NULL,
        "fcmToken"        TEXT            NULL DEFAULT NULL,
        "status"          "user_device_status_enum" NOT NULL DEFAULT 'active',
        "revokedAt"       TIMESTAMPTZ     NULL DEFAULT NULL,
        "revokeReason"    TEXT            NULL DEFAULT NULL,
        "locale"          VARCHAR(8)      NULL DEFAULT NULL,
        "lastSeenAt"      TIMESTAMPTZ     NULL DEFAULT NULL,
        "createdAt"       TIMESTAMPTZ     NOT NULL DEFAULT now(),
        "updatedAt"       TIMESTAMPTZ     NOT NULL DEFAULT now(),
        CONSTRAINT "pk_user_devices" PRIMARY KEY ("id"),
        CONSTRAINT "fk_user_devices_user"
          FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "user_devices_user_idx"
        ON "user_devices" ("userId")
    `);

    await queryRunner.query(`
      CREATE INDEX "user_devices_fingerprint_idx"
        ON "user_devices" ("fingerprintHash")
    `);

    await queryRunner.query(`
      CREATE INDEX "user_devices_fingerprint_created_idx"
        ON "user_devices" ("fingerprintHash", "createdAt")
    `);

    // ── 2. account_flags ────────────────────────────────────────────────────

    await queryRunner.query(`
      CREATE TYPE "account_flag_severity_enum"
        AS ENUM ('low', 'medium', 'high', 'critical')
    `);

    await queryRunner.query(`
      CREATE TYPE "account_flag_disposition_enum"
        AS ENUM ('open', 'resolved', 'dismissed')
    `);

    await queryRunner.query(`
      CREATE TABLE "account_flags" (
        "id"                 UUID        NOT NULL DEFAULT gen_random_uuid(),
        "userId"             UUID        NOT NULL,
        "reason"             VARCHAR(64) NOT NULL,
        "severity"           "account_flag_severity_enum"     NOT NULL DEFAULT 'medium',
        "disposition"        "account_flag_disposition_enum"  NOT NULL DEFAULT 'open',
        "notes"              TEXT        NULL DEFAULT NULL,
        "resolvedByAdminId"  UUID        NULL DEFAULT NULL,
        "resolvedAt"         TIMESTAMPTZ NULL DEFAULT NULL,
        "createdAt"          TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updatedAt"          TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "pk_account_flags" PRIMARY KEY ("id"),
        CONSTRAINT "fk_account_flags_user"
          FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "account_flags_user_idx"
        ON "account_flags" ("userId")
    `);

    await queryRunner.query(`
      CREATE INDEX "account_flags_disposition_idx"
        ON "account_flags" ("disposition")
    `);

    await queryRunner.query(`
      CREATE INDEX "account_flags_created_idx"
        ON "account_flags" ("createdAt")
    `);

    // ── 3. security_events ──────────────────────────────────────────────────

    await queryRunner.query(`
      CREATE TABLE "security_events" (
        "id"           UUID        NOT NULL DEFAULT gen_random_uuid(),
        "userId"       UUID        NULL DEFAULT NULL,
        "eventType"    VARCHAR(64) NOT NULL,
        "deviceId"     UUID        NULL DEFAULT NULL,
        "metadata"     JSONB       NULL DEFAULT NULL,
        "adminActorId" UUID        NULL DEFAULT NULL,
        "createdAt"    TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "pk_security_events" PRIMARY KEY ("id"),
        CONSTRAINT "fk_security_events_user"
          FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "security_events_user_idx"
        ON "security_events" ("userId")
    `);

    await queryRunner.query(`
      CREATE INDEX "security_events_type_idx"
        ON "security_events" ("eventType")
    `);

    await queryRunner.query(`
      CREATE INDEX "security_events_created_idx"
        ON "security_events" ("createdAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Drop in reverse dependency order

    await queryRunner.query(`DROP TABLE IF EXISTS "security_events"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "account_flags"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "user_devices"`);

    await queryRunner.query(
      `DROP TYPE IF EXISTS "account_flag_disposition_enum"`,
    );
    await queryRunner.query(`DROP TYPE IF EXISTS "account_flag_severity_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "user_device_platform_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "user_device_status_enum"`);
  }
}
