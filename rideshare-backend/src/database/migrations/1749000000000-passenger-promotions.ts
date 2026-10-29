import { MigrationInterface, QueryRunner } from 'typeorm';
export class PassengerPromotions1749000000000 implements MigrationInterface {
  async up(q: QueryRunner) {
    await q.query(`CREATE TABLE promotion_campaigns (
      code varchar(32) PRIMARY KEY, percent numeric(5,2) NOT NULL CHECK(percent>0 AND percent<=100),
      "tripType" varchar(16) NOT NULL CHECK("tripType" IN ('all','instant','shared')),
      "startsAt" timestamptz NOT NULL, "endsAt" timestamptz NOT NULL,
      active boolean NOT NULL DEFAULT true, "createdAt" timestamptz NOT NULL DEFAULT now(),
      CHECK("endsAt">"startsAt"))`);
    for (const table of ['bookings', 'instant_ride_requests']) {
      await q.query(
        `ALTER TABLE ${table} ADD COLUMN "promoCode" varchar(32), ADD COLUMN "originalAmount" numeric(12,2), ADD COLUMN "discountAmount" numeric(12,2) NOT NULL DEFAULT 0 CHECK("discountAmount">=0)`,
      );
    }
  }
  async down() {
    throw new Error('Promotion billing history must be retained.');
  }
}
