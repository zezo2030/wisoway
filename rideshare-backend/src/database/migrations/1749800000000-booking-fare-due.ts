import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * `bookings.fareDue`: what the passenger owes once a shared trip ends, for the
 * seats that rode rather than every seat booked.
 *
 * Shared bookings already finished and not yet paid are given theirs now, by
 * the same rule as ridden-fare.ts / seatCountsForCommission, so a passenger
 * still on the payment screen is asked for the right amount.
 */
export class BookingFareDue1749800000000 implements MigrationInterface {
  name = 'BookingFareDue1749800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "fareDue" DECIMAL(10,2) NULL`,
    );
    await queryRunner.query(
      `UPDATE "bookings" b
          SET "fareDue" = round(b."totalAmount" * LEAST(s.rode, b."seatCount") / b."seatCount", 2)
         FROM (
           SELECT bs."bookingId",
                  count(*) FILTER (WHERE CASE
                    WHEN bk."locationVerifiedAt" IS NOT NULL THEN
                      bs."isMainBooker" OR (
                        bs."markedAbsentAt" IS NULL
                        AND bs."passengerDeclaredStatus"::text IS DISTINCT FROM 'not_riding')
                    ELSE
                      bs."passengerSelfConfirmedAt" IS NOT NULL
                      AND bs."billableOverride" IS DISTINCT FROM false
                  END) AS rode
             FROM "booking_seats" bs
             JOIN "bookings" bk ON bk.id = bs."bookingId"
            GROUP BY bs."bookingId"
         ) s, "trips" t
        WHERE s."bookingId" = b.id
          AND t.id = b."tripId"
          AND t."tripType" = 'scheduled'
          AND b.status = 'completed'
          AND b."paymentStatus" IN ('pending', 'failed')
          AND b."seatCount" > 0
          AND b."fareDue" IS NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" DROP COLUMN IF EXISTS "fareDue"`,
    );
  }
}
