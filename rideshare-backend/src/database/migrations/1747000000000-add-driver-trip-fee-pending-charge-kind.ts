import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDriverTripFeePendingChargeKind1747000000000 implements MigrationInterface {
  name = 'AddDriverTripFeePendingChargeKind1747000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    const [{ typname }] = (await queryRunner.query(`
      SELECT t.typname
      FROM pg_type t
      JOIN pg_attribute a ON a.atttypid = t.oid
      JOIN pg_class c ON c.oid = a.attrelid
      WHERE c.relname = 'pending_charges' AND a.attname = 'kind'
    `)) as { typname: string }[];

    await queryRunner.query(
      `ALTER TYPE "${typname}" ADD VALUE IF NOT EXISTS 'driver_trip_fee'`,
    );
  }

  public async down(): Promise<void> {
    // Postgres cannot drop a value from an enum type. Intentionally a no-op:
    // leaving the unused label in place is harmless and reversible-by-restore.
  }
}
