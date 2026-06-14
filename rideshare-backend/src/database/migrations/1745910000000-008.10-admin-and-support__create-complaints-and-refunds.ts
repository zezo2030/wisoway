import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T163 — Migration: 008.10-admin-and-support__create-complaints-and-refunds
 *
 * Creates two new tables:
 *  - `complaints`      — user-filed complaints (T161)
 *  - `refund_requests` — user-filed refund requests (T162)
 *
 * Both tables are additive; no existing data is modified.
 */
export class AdminAndSupportCreateComplaintsAndRefunds1745910000000 implements MigrationInterface {
  name = 'AdminAndSupportCreateComplaintsAndRefunds1745910000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── complaints ─────────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "complaints" (
        "id"                  uuid              NOT NULL DEFAULT gen_random_uuid(),
        "reporterId"          uuid              NOT NULL,
        "againstUserId"       uuid              DEFAULT NULL,
        "tripId"              uuid              DEFAULT NULL,
        "bookingId"           uuid              DEFAULT NULL,
        "category"            varchar(32)       NOT NULL,
        "body"                text              NOT NULL,
        "status"              varchar(16)       NOT NULL DEFAULT 'open',
        "adminNotes"          text              DEFAULT NULL,
        "resolvedByAdminId"   uuid              DEFAULT NULL,
        "resolvedAt"          timestamptz       DEFAULT NULL,
        "createdAt"           timestamptz       NOT NULL DEFAULT now(),
        "updatedAt"           timestamptz       NOT NULL DEFAULT now(),
        CONSTRAINT "pk_complaints" PRIMARY KEY ("id"),
        CONSTRAINT "fk_complaints_reporter"
          FOREIGN KEY ("reporterId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "fk_complaints_against_user"
          FOREIGN KEY ("againstUserId") REFERENCES "users"("id") ON DELETE SET NULL,
        CONSTRAINT "fk_complaints_trip"
          FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE SET NULL,
        CONSTRAINT "fk_complaints_booking"
          FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE SET NULL
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_complaints_status_created"
        ON "complaints" ("status", "createdAt")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_complaints_against_user"
        ON "complaints" ("againstUserId")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_complaints_reporter"
        ON "complaints" ("reporterId")
    `);

    // ── refund_requests ────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "refund_requests" (
        "id"                  uuid              NOT NULL DEFAULT gen_random_uuid(),
        "userId"              uuid              NOT NULL,
        "bookingId"           uuid              DEFAULT NULL,
        "amount"              numeric(10,2)     DEFAULT NULL,
        "currency"            varchar(5)        NOT NULL DEFAULT 'JOD',
        "reason"              text              NOT NULL,
        "status"              varchar(16)       NOT NULL DEFAULT 'open',
        "whatsappContactedAt" timestamptz       DEFAULT NULL,
        "resolvedByAdminId"   uuid              DEFAULT NULL,
        "resolvedAt"          timestamptz       DEFAULT NULL,
        "adminNotes"          text              DEFAULT NULL,
        "createdAt"           timestamptz       NOT NULL DEFAULT now(),
        "updatedAt"           timestamptz       NOT NULL DEFAULT now(),
        CONSTRAINT "pk_refund_requests" PRIMARY KEY ("id"),
        CONSTRAINT "fk_refund_requests_user"
          FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "fk_refund_requests_booking"
          FOREIGN KEY ("bookingId") REFERENCES "bookings"("id") ON DELETE SET NULL
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_refund_requests_status_created"
        ON "refund_requests" ("status", "createdAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "refund_requests"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "complaints"`);
  }
}
