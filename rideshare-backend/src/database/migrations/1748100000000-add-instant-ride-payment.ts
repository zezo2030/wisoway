import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Ride fares (instant rides and shared trips) are paid cash to the driver,
 * who confirms it, or by CliQ request-to-pay to the platform at the end of
 * the ride, after which the platform credits the driver's wallet. The state
 * lives on the booking; the passenger's end-of-trip screen waits on it.
 */
export class AddInstantRidePayment1748100000000 implements MigrationInterface {
  name = 'AddInstantRidePayment1748100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "cliqAlias" varchar(100)`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "paymentMethod" varchar(10) NOT NULL DEFAULT 'cash'`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "payerCliqAlias" varchar(100)`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "paymentMethod" varchar(10) NOT NULL DEFAULT 'cash'`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "paymentStatus" varchar(12) NOT NULL DEFAULT 'pending'`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "paymentDisputedAt" TIMESTAMPTZ NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "payerCliqAlias" varchar(100)`,
    );
    // Rides that ended before this existed were never waiting on a payment
    // answer: count them as paid so nobody lands on a payment screen.
    await queryRunner.query(
      `UPDATE "bookings" SET "paymentStatus" = 'paid',
              "settledAt" = COALESCE("settledAt", "updatedAt")
        WHERE "status" IN ('completed', 'no_show')`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    for (const column of [
      'payerCliqAlias',
      'paymentDisputedAt',
      'paymentStatus',
      'paymentMethod',
    ]) {
      await queryRunner.query(
        `ALTER TABLE "bookings" DROP COLUMN IF EXISTS "${column}"`,
      );
    }
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "payerCliqAlias"`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "paymentMethod"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "cliqAlias"`,
    );
  }
}
