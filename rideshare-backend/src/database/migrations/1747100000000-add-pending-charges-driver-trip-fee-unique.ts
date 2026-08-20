import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * One driver_trip_fee charge per trip, enforced by the database.
 *
 * DriverTripFeeService checks for an existing charge before recording a
 * shortfall, but that check and the insert are not atomic: two callers racing
 * the same trip start (the auto-start retry and the reconciliation sweep) can
 * both pass the check and both record. PendingChargesService.record also
 * attempts an immediate wallet deduction, so a double record can become a
 * double debit when the balance covers it.
 *
 * Partial on purpose: the other charge kinds legitimately allow several rows
 * per trip, so the constraint is scoped to this one label. The label itself is
 * added by 1747000000000, which therefore has to run first.
 */
export class AddPendingChargesDriverTripFeeUnique1747100000000 implements MigrationInterface {
  name = 'AddPendingChargesDriverTripFeeUnique1747100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "uq_pending_charges_trip_driver_fee"
        ON "pending_charges" ("tripId", "kind")
        WHERE "kind" = 'driver_trip_fee'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "uq_pending_charges_trip_driver_fee"`,
    );
  }
}
