import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T095 — Migration: extend trips status enum + add time-flow columns
 *
 * Phase 5 / 008-platform-completion / US3 / 011-trip-time-flow
 *
 * - Extends the `trips.status` enum with: draft, published, fully_booked, in_progress
 * - Backfills `active → published` (R-008: response serializer still emits "active"
 *   for one release so mobile clients are not broken)
 * - Adds: tripStartedAt, tripCompletedAt, noShowMarkedAt,
 *         lastDriverLocationLat, lastDriverLocationLng, lastDriverLocationAt,
 *         preTripConfirmSentAt, stops (jsonb), notes (text)
 */
export class TripTimeFlow06TripsExtend1745906000000 implements MigrationInterface {
  name = 'TripTimeFlow06TripsExtend1745906000000';
  transaction = false; // ALTER TYPE ADD VALUE cannot be used in same transaction as the new value

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── 1. Extend the enum (PostgreSQL requires ALTER TYPE … ADD VALUE) ──────
    // Each ADD VALUE is idempotent across re-runs via the IF NOT EXISTS guard
    // (requires PostgreSQL 12+, which we have).
    await queryRunner.query(
      `ALTER TYPE "trip_status_enum" ADD VALUE IF NOT EXISTS 'draft'`,
    );
    await queryRunner.query(
      `ALTER TYPE "trip_status_enum" ADD VALUE IF NOT EXISTS 'published'`,
    );
    await queryRunner.query(
      `ALTER TYPE "trip_status_enum" ADD VALUE IF NOT EXISTS 'fully_booked'`,
    );
    await queryRunner.query(
      `ALTER TYPE "trip_status_enum" ADD VALUE IF NOT EXISTS 'in_progress'`,
    );

    // ── 2. Backfill active → published ─────────────────────────────────────
    // "active" is kept in the enum for one release (R-008 compat shim).
    await queryRunner.query(
      `UPDATE "trips" SET "status" = 'published' WHERE "status" = 'active'`,
    );

    // ── 3. Add new columns ──────────────────────────────────────────────────
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "tripStartedAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "tripCompletedAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "noShowMarkedAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "lastDriverLocationLat" FLOAT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "lastDriverLocationLng" FLOAT NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "lastDriverLocationAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "preTripConfirmSentAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "stops" JSONB NOT NULL DEFAULT '[]'`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "notes" TEXT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Restore active rows from published (best-effort; cannot remove enum values in PG)
    await queryRunner.query(
      `UPDATE "trips" SET "status" = 'active' WHERE "status" = 'published'`,
    );

    for (const col of [
      'tripStartedAt',
      'tripCompletedAt',
      'noShowMarkedAt',
      'lastDriverLocationLat',
      'lastDriverLocationLng',
      'lastDriverLocationAt',
      'preTripConfirmSentAt',
      'stops',
      'notes',
    ]) {
      await queryRunner.query(
        `ALTER TABLE "trips" DROP COLUMN IF EXISTS "${col}"`,
      );
    }
  }
}
