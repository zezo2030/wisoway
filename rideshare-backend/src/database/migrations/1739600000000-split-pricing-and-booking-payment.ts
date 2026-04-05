import { MigrationInterface, QueryRunner } from 'typeorm';

export class SplitPricingAndBookingPayment1739600000000 implements MigrationInterface {
  name = 'SplitPricingAndBookingPayment1739600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE communication_fees
      ADD COLUMN IF NOT EXISTS "passengerPlatformPercent" DECIMAL(5,2) NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS "driverUnlockPercent" DECIMAL(5,2) NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS "lifetimeFreeTripEnabled" BOOLEAN NOT NULL DEFAULT TRUE
    `);

    await queryRunner.query(`
      ALTER TABLE bookings
      ADD COLUMN IF NOT EXISTS "seatPriceAtBooking" DECIMAL(10,2),
      ADD COLUMN IF NOT EXISTS "platformAmount" DECIMAL(10,2),
      ADD COLUMN IF NOT EXISTS "driverAmount" DECIMAL(10,2),
      ADD COLUMN IF NOT EXISTS "passengerPaymentId" UUID
    `);

    // payments table may exist from TypeORM sync or a manual schema; skip FK if missing.
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = 'public' AND table_name = 'payments'
        ) AND NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'fk_bookings_passenger_payment'
        ) THEN
          ALTER TABLE bookings
          ADD CONSTRAINT fk_bookings_passenger_payment
          FOREIGN KEY ("passengerPaymentId") REFERENCES payments(id) ON DELETE SET NULL;
        END IF;
      END $$;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE bookings DROP CONSTRAINT IF EXISTS fk_bookings_passenger_payment
    `);
    await queryRunner.query(`
      ALTER TABLE bookings
      DROP COLUMN IF EXISTS "passengerPaymentId",
      DROP COLUMN IF EXISTS "driverAmount",
      DROP COLUMN IF EXISTS "platformAmount",
      DROP COLUMN IF EXISTS "seatPriceAtBooking"
    `);
    await queryRunner.query(`
      ALTER TABLE communication_fees
      DROP COLUMN IF EXISTS "lifetimeFreeTripEnabled",
      DROP COLUMN IF EXISTS "driverUnlockPercent",
      DROP COLUMN IF EXISTS "passengerPlatformPercent"
    `);
  }
}
