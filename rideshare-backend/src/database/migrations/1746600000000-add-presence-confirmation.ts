import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 012-passenger-presence-confirmation — schema foundation.
 *
 * Adds the columns needed to (a) record who was physically present in the
 * vehicle and (b) settle the driver's platform fee against confirmed-present
 * seats only, backed by a wallet hold placed at contact-unlock.
 *
 * Billing rule (DD-5, approved): every accepted seat is billable BY DEFAULT.
 * A seat becomes non-billable only when the driver explicitly marks it absent
 * before the trip is finalised.  `billableOverride` is therefore three-valued:
 *
 *   NULL  → default, billable
 *   false → driver explicitly marked absent and the passenger did not contradict
 *   true  → forced billable (driver/passenger conflict, or admin resolution)
 *
 * All additions are nullable or defaulted, so this migration is safe to deploy
 * ahead of the application code.
 *
 * DOWN PATH WARNING: dropping `wallet_accounts.reservedBalance` discards the
 * reservation ledger.  Any hold still in `status = 'active'` must be settled or
 * released BEFORE rolling back, otherwise the reserved funds become invisible
 * and drivers can overdraw.  The down() below force-releases active holds first.
 */
export class AddPresenceConfirmation1746600000000 implements MigrationInterface {
  name = 'AddPresenceConfirmation1746600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── booking_seats: presence evidence from both sides ────────────────────
    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        ADD COLUMN IF NOT EXISTS "passengerSelfConfirmedAt" TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS "passengerDeclaredStatus" VARCHAR(20) NULL,
        ADD COLUMN IF NOT EXISTS "autoFlaggedAbsentAt" TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS "absenceReason" VARCHAR(30) NULL,
        ADD COLUMN IF NOT EXISTS "billableOverride" BOOLEAN NULL,
        ADD COLUMN IF NOT EXISTS "presenceDisputedAt" TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS "presenceResolvedBy" UUID NULL,
        ADD COLUMN IF NOT EXISTS "presenceResolutionNote" TEXT NULL,
        ADD COLUMN IF NOT EXISTS "presenceUpdatedAt" TIMESTAMPTZ NULL
    `);

    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        DROP CONSTRAINT IF EXISTS "chk_booking_seats_declared_status"
    `);
    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        ADD CONSTRAINT "chk_booking_seats_declared_status"
        CHECK ("passengerDeclaredStatus" IS NULL
               OR "passengerDeclaredStatus" IN ('in_vehicle', 'on_my_way', 'not_riding'))
    `);

    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        DROP CONSTRAINT IF EXISTS "chk_booking_seats_absence_reason"
    `);
    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        ADD CONSTRAINT "chk_booking_seats_absence_reason"
        CHECK ("absenceReason" IS NULL
               OR "absenceReason" IN ('no_show', 'cancelled_on_site', 'wrong_pickup', 'other'))
    `);

    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        ADD CONSTRAINT "fk_booking_seats_presence_resolved_by"
        FOREIGN KEY ("presenceResolvedBy") REFERENCES "users"("id") ON DELETE SET NULL
    `);

    // Settlement scans seats of a trip filtered by billability.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_booking_seats_presence"
        ON "booking_seats" ("bookingId", "billableOverride")
    `);
    // Admin dispute queue.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_booking_seats_disputed"
        ON "booking_seats" ("presenceDisputedAt")
        WHERE "presenceDisputedAt" IS NOT NULL
    `);

    // ── trips: frozen settlement outcome ────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD COLUMN IF NOT EXISTS "presenceSettledAt" TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS "billableSeatCount" INTEGER NULL,
        ADD COLUMN IF NOT EXISTS "capturedFeeAmount" NUMERIC(10,2) NULL,
        ADD COLUMN IF NOT EXISTS "driverFeeHoldId" UUID NULL,
        ADD COLUMN IF NOT EXISTS "presenceReviewFlagged" BOOLEAN NOT NULL DEFAULT false
    `);

    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD CONSTRAINT "fk_trips_driver_fee_hold"
        FOREIGN KEY ("driverFeeHoldId") REFERENCES "wallet_holds"("id") ON DELETE SET NULL
    `);

    // Reconciliation job: completed trips that never settled.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_trips_presence_unsettled"
        ON "trips" ("tripCompletedAt")
        WHERE "presenceSettledAt" IS NULL AND "driverFeeHoldId" IS NOT NULL
    `);

    // ── wallet_accounts: reserved (held) funds ──────────────────────────────
    // available = balance - reservedBalance.  Existing rows get 0 because no
    // hold has ever been written (wallet_holds is empty in every environment).
    await queryRunner.query(`
      ALTER TABLE "wallet_accounts"
        ADD COLUMN IF NOT EXISTS "reservedBalance" NUMERIC(14,2) NOT NULL DEFAULT '0'
    `);
    await queryRunner.query(`
      ALTER TABLE "wallet_accounts"
        ADD CONSTRAINT "chk_wallet_accounts_reserved_non_negative"
        CHECK ("reservedBalance" >= 0)
    `);

    // ── wallet_holds: capture/release bookkeeping ───────────────────────────
    await queryRunner.query(`
      ALTER TABLE "wallet_holds"
        ADD COLUMN IF NOT EXISTS "capturedAmount" NUMERIC(14,2) NULL,
        ADD COLUMN IF NOT EXISTS "releasedAmount" NUMERIC(14,2) NULL,
        ADD COLUMN IF NOT EXISTS "settledAt" TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS "metadata" JSONB NULL
    `);

    // One active hold per trip — the idempotency guard for placeHold().
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "uq_wallet_holds_active_reference"
        ON "wallet_holds" ("referenceType", "referenceId")
        WHERE "status" = 'active'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Release any still-active hold back into the accounts BEFORE the
    // reservedBalance column disappears, otherwise the reservation is lost
    // while the funds stay silently unavailable.
    await queryRunner.query(`
      UPDATE "wallet_accounts" a
         SET "reservedBalance" = 0
       WHERE EXISTS (
         SELECT 1 FROM "wallet_holds" h
          WHERE h."accountId" = a."id" AND h."status" = 'active'
       )
    `);
    await queryRunner.query(`
      UPDATE "wallet_holds"
         SET "status" = 'released', "settledAt" = NOW()
       WHERE "status" = 'active'
    `);

    await queryRunner.query(
      `DROP INDEX IF EXISTS "uq_wallet_holds_active_reference"`,
    );
    await queryRunner.query(`
      ALTER TABLE "wallet_holds"
        DROP COLUMN IF EXISTS "capturedAmount",
        DROP COLUMN IF EXISTS "releasedAmount",
        DROP COLUMN IF EXISTS "settledAt",
        DROP COLUMN IF EXISTS "metadata"
    `);

    await queryRunner.query(
      `ALTER TABLE "wallet_accounts" DROP CONSTRAINT IF EXISTS "chk_wallet_accounts_reserved_non_negative"`,
    );
    await queryRunner.query(
      `ALTER TABLE "wallet_accounts" DROP COLUMN IF EXISTS "reservedBalance"`,
    );

    await queryRunner.query(`DROP INDEX IF EXISTS "idx_trips_presence_unsettled"`);
    await queryRunner.query(
      `ALTER TABLE "trips" DROP CONSTRAINT IF EXISTS "fk_trips_driver_fee_hold"`,
    );
    await queryRunner.query(`
      ALTER TABLE "trips"
        DROP COLUMN IF EXISTS "presenceSettledAt",
        DROP COLUMN IF EXISTS "billableSeatCount",
        DROP COLUMN IF EXISTS "capturedFeeAmount",
        DROP COLUMN IF EXISTS "driverFeeHoldId",
        DROP COLUMN IF EXISTS "presenceReviewFlagged"
    `);

    await queryRunner.query(`DROP INDEX IF EXISTS "idx_booking_seats_disputed"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_booking_seats_presence"`);
    await queryRunner.query(
      `ALTER TABLE "booking_seats" DROP CONSTRAINT IF EXISTS "fk_booking_seats_presence_resolved_by"`,
    );
    await queryRunner.query(
      `ALTER TABLE "booking_seats" DROP CONSTRAINT IF EXISTS "chk_booking_seats_absence_reason"`,
    );
    await queryRunner.query(
      `ALTER TABLE "booking_seats" DROP CONSTRAINT IF EXISTS "chk_booking_seats_declared_status"`,
    );
    await queryRunner.query(`
      ALTER TABLE "booking_seats"
        DROP COLUMN IF EXISTS "passengerSelfConfirmedAt",
        DROP COLUMN IF EXISTS "passengerDeclaredStatus",
        DROP COLUMN IF EXISTS "autoFlaggedAbsentAt",
        DROP COLUMN IF EXISTS "absenceReason",
        DROP COLUMN IF EXISTS "billableOverride",
        DROP COLUMN IF EXISTS "presenceDisputedAt",
        DROP COLUMN IF EXISTS "presenceResolvedBy",
        DROP COLUMN IF EXISTS "presenceResolutionNote",
        DROP COLUMN IF EXISTS "presenceUpdatedAt"
    `);
  }
}
