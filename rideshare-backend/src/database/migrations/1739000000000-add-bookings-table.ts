import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddBookingsTable1739000000000 implements MigrationInterface {
  name = 'AddBookingsTable1739000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS bookings (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "tripId" UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        "userId" UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        "seatNumber" VARCHAR NOT NULL,
        status VARCHAR NOT NULL DEFAULT 'pending',
        "hasDriverPaidToContact" BOOLEAN NOT NULL DEFAULT FALSE,
        "sharePhoneWithDriver" BOOLEAN NOT NULL DEFAULT FALSE,
        "cancellationReason" TEXT,
        "cancelledAt" TIMESTAMPTZ,
        "cancelledBy" VARCHAR,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT bookings_user_trip_unique UNIQUE ("userId", "tripId")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_bookings_user_trip ON bookings ("userId", "tripId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_bookings_trip ON bookings ("tripId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_bookings_user ON bookings ("userId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings (status)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS bookings`);
  }
}
