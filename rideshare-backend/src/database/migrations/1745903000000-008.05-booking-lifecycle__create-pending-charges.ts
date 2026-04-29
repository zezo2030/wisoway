import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T063 — Migration: create pending_charges table
 *
 * Phase 4 / 008-platform-completion / US2 / 010-booking-lifecycle
 */
export class BookingLifecycle05CreatePendingCharges1745903000000 implements MigrationInterface {
  name = 'BookingLifecycle05CreatePendingCharges1745903000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Enum types
    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pending_charge_kind_enum') THEN
          CREATE TYPE "pending_charge_kind_enum" AS ENUM (
            'passenger_cancellation',
            'driver_no_show',
            'passenger_no_show'
          );
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pending_charge_status_enum') THEN
          CREATE TYPE "pending_charge_status_enum" AS ENUM (
            'pending',
            'applied',
            'waived'
          );
        END IF;
      END$$
    `);

    // 2. Table
    await queryRunner.query(`
      CREATE TABLE "pending_charges" (
        "id"                  UUID          NOT NULL DEFAULT gen_random_uuid(),
        "userId"              UUID          NOT NULL,
        "kind"                "pending_charge_kind_enum"   NOT NULL,
        "amount"              DECIMAL(10,2) NOT NULL,
        "status"              "pending_charge_status_enum" NOT NULL DEFAULT 'pending',
        "bookingId"           UUID          NULL,
        "tripId"              UUID          NULL,
        "walletTransactionId" UUID          NULL,
        "appliedToBookingId"  UUID          NULL,
        "waivedByAdminId"     UUID          NULL,
        "waivedAt"            TIMESTAMP     NULL,
        "createdAt"           TIMESTAMP     NOT NULL DEFAULT now(),
        "updatedAt"           TIMESTAMP     NOT NULL DEFAULT now(),
        CONSTRAINT "PK_pending_charges" PRIMARY KEY ("id"),
        CONSTRAINT "FK_pending_charges_user"
          FOREIGN KEY ("userId")    REFERENCES "users"("id")     ON DELETE CASCADE,
        CONSTRAINT "FK_pending_charges_booking"
          FOREIGN KEY ("bookingId") REFERENCES "bookings"("id")  ON DELETE SET NULL,
        CONSTRAINT "FK_pending_charges_trip"
          FOREIGN KEY ("tripId")    REFERENCES "trips"("id")     ON DELETE SET NULL
      )
    `);

    // 3. Indexes
    await queryRunner.query(`
      CREATE INDEX "idx_pending_charges_user_status"
        ON "pending_charges" ("userId", "status")
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_pending_charges_booking"
        ON "pending_charges" ("bookingId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "pending_charges"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "pending_charge_kind_enum"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "pending_charge_status_enum"`);
  }
}
