import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Passenger-priced instant rides + driver counter-offers:
 * - requests: distance-based recommendation, the passenger's asking fare, and
 *   the immutable fare agreed at match time.
 * - offers: the driver's counter-offer amount ("countered"/"rejected" statuses
 *   reuse the existing varchar status column).
 */
export class AddInstantFareNegotiation1746500000000 implements MigrationInterface {
  name = 'AddInstantFareNegotiation1746500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      ADD COLUMN IF NOT EXISTS "recommendedFare" numeric(10,2),
      ADD COLUMN IF NOT EXISTS "passengerFare" numeric(10,2),
      ADD COLUMN IF NOT EXISTS "acceptedFare" numeric(10,2)
    `);
    await queryRunner.query(`
      ALTER TABLE "instant_ride_offers"
      ADD COLUMN IF NOT EXISTS "proposedFare" numeric(10,2)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "instant_ride_offers" DROP COLUMN IF EXISTS "proposedFare"
    `);
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      DROP COLUMN IF EXISTS "recommendedFare",
      DROP COLUMN IF EXISTS "passengerFare",
      DROP COLUMN IF EXISTS "acceptedFare"
    `);
  }
}
