import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * A driver's own rating: only what passengers gave them as a driver
 * (ratings.ratedRole = 'driver'), scaled by the late-pickup penalty factor.
 * `users.rating` keeps mixing every rating a user received, so an account
 * that both drives and rides no longer shows passengers a blend of the two.
 * Backfilled from the existing ratings.
 */
export class AddUserDriverRating1748500000000 implements MigrationInterface {
  name = 'AddUserDriverRating1748500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "driverRating" DECIMAL(3,2) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "driverTotalRatings" INT NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `UPDATE "users" u
         SET "driverTotalRatings" = s.cnt,
             "driverRating" = GREATEST(1, ROUND((s.avg * u."ratingPenaltyFactor")::numeric, 1))
        FROM (
          SELECT "toUserId", COUNT(*)::int AS cnt, AVG(rating)::numeric AS avg
            FROM "ratings"
           WHERE "ratedRole" = 'driver'
           GROUP BY "toUserId"
        ) s
       WHERE s."toUserId" = u.id`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "driverTotalRatings"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN IF EXISTS "driverRating"`,
    );
  }
}
