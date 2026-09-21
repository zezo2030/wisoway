import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Creates the `ratings` table.
 *
 * `RatingEntity` has been registered with TypeORM and served by
 * RatingsModule since the Postgres migration, but no migration ever created
 * its table — `synchronize` is off, so the relation simply never existed.
 * Every ratings endpoint therefore failed with
 * `relation "ratings" does not exist`: reads returned 500 and no rating could
 * be written at all, which also left `users.rating` / `users.totalRatings`
 * permanently at zero.
 *
 * The shape below mirrors `rating.entity.ts` exactly, including the unique
 * index on (fromUserId, tripId) that enforces "one rating per rater per trip".
 */
export class CreateRatings1747700000000 implements MigrationInterface {
  name = 'CreateRatings1747700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "ratings" (
        "id"         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "fromUserId" UUID NOT NULL,
        "toUserId"   UUID NOT NULL,
        "tripId"     UUID NOT NULL,
        "rating"     INTEGER NOT NULL,
        "comment"    TEXT NULL,
        "userRole"   VARCHAR NULL,
        "ratedRole"  VARCHAR NULL,
        "createdAt"  TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt"  TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "fk_ratings_from_user"
          FOREIGN KEY ("fromUserId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "fk_ratings_to_user"
          FOREIGN KEY ("toUserId") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "fk_ratings_trip"
          FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE CASCADE,
        CONSTRAINT "chk_ratings_value" CHECK ("rating" BETWEEN 1 AND 5)
      )
    `);

    // One rating per rater per trip — the entity's @Index(..., { unique: true }).
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "idx_ratings_from_user_trip"
        ON "ratings" ("fromUserId", "tripId")
    `);

    // Read paths: "ratings received by user", "ratings on this trip".
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_ratings_to_user"
        ON "ratings" ("toUserId")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_ratings_trip"
        ON "ratings" ("tripId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Dropping this table discards every rating ever submitted, and the
    // aggregates on `users` are not recomputable from anything else.
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_ratings_trip"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_ratings_to_user"`);
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_ratings_from_user_trip"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "ratings"`);
  }
}
