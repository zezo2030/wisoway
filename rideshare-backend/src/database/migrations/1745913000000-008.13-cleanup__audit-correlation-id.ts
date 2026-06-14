import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T187 — Migration: 008.13-cleanup__audit-correlation-id
 *
 * Adds a nullable `correlationId` varchar column to three audit/event tables:
 *  - `security_events`
 *  - `settlement_audits`
 *  - `pending_charges`
 *
 * Purpose:
 *  Allows incoming HTTP request IDs (e.g. from an `X-Request-ID` header or
 *  a gateway-assigned trace ID) to be recorded alongside the audit row so
 *  that a single request can be traced end-to-end across logs, audit rows,
 *  and job queues.
 *
 *  The column is nullable because background BullMQ jobs that create audit
 *  rows do not always have an originating HTTP request ID.
 *
 * Phase 9 / T187 — 008-platform-completion.
 */
export class CleanupAuditCorrelationId1745913000000 implements MigrationInterface {
  name = 'CleanupAuditCorrelationId1745913000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "security_events"
        ADD COLUMN IF NOT EXISTS "correlationId" varchar DEFAULT NULL
    `);

    await queryRunner.query(`
      ALTER TABLE "settlement_audits"
        ADD COLUMN IF NOT EXISTS "correlationId" varchar DEFAULT NULL
    `);

    await queryRunner.query(`
      ALTER TABLE "pending_charges"
        ADD COLUMN IF NOT EXISTS "correlationId" varchar DEFAULT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "pending_charges"
        DROP COLUMN IF EXISTS "correlationId"
    `);
    await queryRunner.query(`
      ALTER TABLE "settlement_audits"
        DROP COLUMN IF EXISTS "correlationId"
    `);
    await queryRunner.query(`
      ALTER TABLE "security_events"
        DROP COLUMN IF EXISTS "correlationId"
    `);
  }
}
