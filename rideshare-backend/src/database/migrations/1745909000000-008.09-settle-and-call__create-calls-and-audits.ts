import { MigrationInterface, QueryRunner } from 'typeorm';

export class SettleAndCall091745909000000 implements MigrationInterface {
  name = 'SettleAndCall091745909000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── settlement_audits ─────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "settlement_audits" (
        "id"        UUID        NOT NULL DEFAULT gen_random_uuid(),
        "bookingId" UUID        NOT NULL,
        "action"    VARCHAR(20) NOT NULL
                    CHECK ("action" IN ('mark_paid', 'unmark_paid', 'admin_revert')),
        "actorId"   UUID        NOT NULL,
        "reason"    TEXT,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_settlement_audits" PRIMARY KEY ("id"),
        CONSTRAINT "FK_settlement_audits_booking"
          FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_settlement_audits_actor"
          FOREIGN KEY ("actorId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_settlement_audits_booking"
        ON "settlement_audits" ("bookingId");
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_settlement_audits_actor"
        ON "settlement_audits" ("actorId");
    `);

    // ── call_sessions ─────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "call_sessions" (
        "id"                UUID         NOT NULL DEFAULT gen_random_uuid(),
        "bookingId"         UUID         NOT NULL,
        "callerUserId"      UUID         NOT NULL,
        "calleeUserId"      UUID         NOT NULL,
        "proxyNumber"       VARCHAR(20)  NOT NULL,
        "callerRealNumber"  VARCHAR(20),
        "calleeRealNumber"  VARCHAR(20),
        "twilioCallSid"     VARCHAR(64)  UNIQUE,
        "status"            VARCHAR(20)  NOT NULL DEFAULT 'initiated'
                            CHECK ("status" IN ('initiated', 'in_progress', 'completed', 'failed')),
        "startedAt"         TIMESTAMPTZ,
        "endedAt"           TIMESTAMPTZ,
        "durationSeconds"   INT,
        "terminationReason" VARCHAR(40),
        "createdAt"         TIMESTAMPTZ  NOT NULL DEFAULT now(),
        "updatedAt"         TIMESTAMPTZ  NOT NULL DEFAULT now(),
        CONSTRAINT "PK_call_sessions" PRIMARY KEY ("id"),
        CONSTRAINT "FK_call_sessions_booking"
          FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_call_sessions_caller"
          FOREIGN KEY ("callerUserId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_call_sessions_callee"
          FOREIGN KEY ("calleeUserId") REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_call_sessions_booking"
        ON "call_sessions" ("bookingId");
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_call_sessions_twilio_sid"
        ON "call_sessions" ("twilioCallSid")
        WHERE "twilioCallSid" IS NOT NULL;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "call_sessions";`);
    await queryRunner.query(`DROP TABLE IF EXISTS "settlement_audits";`);
  }
}
