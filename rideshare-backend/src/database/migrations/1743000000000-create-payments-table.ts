import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePaymentsTable1743000000000 implements MigrationInterface {
  name = 'CreatePaymentsTable1743000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS payments (
        id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "tripId"    UUID,
        "bookingId" UUID,
        "userId"    UUID NOT NULL,
        amount      DECIMAL(12, 2) NOT NULL,
        currency    VARCHAR(5)  NOT NULL DEFAULT 'EGP',
        method      VARCHAR     NOT NULL,
        status      VARCHAR     NOT NULL DEFAULT 'pending',
        "paymentType" VARCHAR   NOT NULL DEFAULT 'trip',
        direction   VARCHAR,
        "proofImageUrl"       TEXT,
        "walletNumber"        VARCHAR,
        "transactionId"       VARCHAR,
        "paymentGatewayRef"   VARCHAR,
        "recipientAliasType"  VARCHAR,
        "recipientAliasValue" VARCHAR,
        "adminNote"  TEXT,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),

        CONSTRAINT fk_payments_user
          FOREIGN KEY ("userId") REFERENCES users(id) ON DELETE RESTRICT,

        CONSTRAINT fk_payments_trip
          FOREIGN KEY ("tripId") REFERENCES trips(id) ON DELETE SET NULL,

        CONSTRAINT fk_payments_booking
          FOREIGN KEY ("bookingId") REFERENCES bookings(id) ON DELETE SET NULL
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS idx_payments_user    ON payments ("userId");
      CREATE INDEX IF NOT EXISTS idx_payments_trip    ON payments ("tripId");
      CREATE INDEX IF NOT EXISTS idx_payments_booking ON payments ("bookingId");
      CREATE INDEX IF NOT EXISTS idx_payments_status  ON payments (status);
    `);

    /* Re-add the FK on bookings that references payments, now that the table exists */
    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'fk_bookings_passenger_payment'
        ) AND EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'bookings' AND column_name = 'passengerPaymentId'
        ) THEN
          ALTER TABLE bookings
            ADD CONSTRAINT fk_bookings_passenger_payment
            FOREIGN KEY ("passengerPaymentId") REFERENCES payments(id) ON DELETE SET NULL;
        END IF;
      END $$;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE bookings DROP CONSTRAINT IF EXISTS fk_bookings_passenger_payment`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS payments`);
  }
}
