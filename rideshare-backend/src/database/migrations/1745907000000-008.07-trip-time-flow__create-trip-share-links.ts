import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * T096 — Migration: create trip_share_links table
 *
 * Phase 5 / 008-platform-completion / US3 / 011-trip-time-flow
 *
 * - Creates `trip_share_links` with a unique random `token` column
 * - Indexes: unique on token, non-unique on tripId
 */
export class TripTimeFlow07CreateTripShareLinks1745907000000 implements MigrationInterface {
  name = 'TripTimeFlow07CreateTripShareLinks1745907000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "trip_share_links" (
        "id"                UUID          NOT NULL DEFAULT gen_random_uuid(),
        "tripId"            UUID          NOT NULL,
        "createdByUserId"   UUID          NOT NULL,
        "token"             VARCHAR(64)   NOT NULL,
        "expiresAt"         TIMESTAMPTZ   NOT NULL,
        "createdAt"         TIMESTAMPTZ   NOT NULL DEFAULT now(),
        CONSTRAINT "PK_trip_share_links" PRIMARY KEY ("id"),
        CONSTRAINT "FK_trip_share_links_trip"
          FOREIGN KEY ("tripId") REFERENCES "trips"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX "idx_trip_share_links_token"
        ON "trip_share_links" ("token")
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_trip_share_links_trip"
        ON "trip_share_links" ("tripId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "trip_share_links"`);
  }
}
