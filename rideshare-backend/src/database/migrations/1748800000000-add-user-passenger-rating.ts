import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * A passenger's own rating — what drivers gave them as a passenger
 * (ratings.ratedRole = 'passenger') — shown to drivers on ride requests and
 * bookings, with its own penalty factor (cancelling an accepted ride).
 * Backfilled from the existing ratings.
 */
export class AddUserPassengerRating1748800000000 implements MigrationInterface {
  name = 'AddUserPassengerRating1748800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "passengerRating" DECIMAL(3,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "passengerTotalRatings" INT NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "passengerRatingPenaltyFactor" DECIMAL(6,4) NOT NULL DEFAULT 1`,
    );
    await queryRunner.query(
      `UPDATE "users" u
         SET "passengerTotalRatings" = s.cnt,
             "passengerRating" = GREATEST(1, ROUND(s.avg::numeric, 1))
        FROM (
          SELECT "toUserId", COUNT(*)::int AS cnt, AVG(rating)::numeric AS avg
            FROM "ratings"
           WHERE "ratedRole" = 'passenger'
           GROUP BY "toUserId"
        ) s
       WHERE s."toUserId" = u.id`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "passengerRatingPenaltyFactor"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "passengerTotalRatings"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "passengerRating"`,
    );
  }
}
