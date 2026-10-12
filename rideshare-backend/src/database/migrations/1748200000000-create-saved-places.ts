import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Creates `saved_places`: a user's Home, Work and named shortcut places, kept
 * on the account so they follow the user across devices. Mirrors
 * `saved-place.entity.ts`, including the unique (userId, kind, label) index —
 * Home and Work carry an empty label, which makes each a singleton per user.
 */
export class CreateSavedPlaces1748200000000 implements MigrationInterface {
  name = 'CreateSavedPlaces1748200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "saved_places_kind_enum" AS ENUM ('home', 'work', 'custom');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$
    `);
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "saved_places" (
        "id"            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "userId"        UUID NOT NULL,
        "kind"          "saved_places_kind_enum" NOT NULL,
        "label"         VARCHAR(30) NOT NULL DEFAULT '',
        "name"          VARCHAR(200) NOT NULL,
        "secondaryText" VARCHAR(300) NOT NULL DEFAULT '',
        "latitude"      DOUBLE PRECISION NOT NULL,
        "longitude"     DOUBLE PRECISION NOT NULL,
        "createdAt"     TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt"     TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "fk_saved_places_user"
          FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "uq_saved_places_user_kind_label"
        ON "saved_places" ("userId", "kind", "label")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "uq_saved_places_user_kind_label"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "saved_places"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "saved_places_kind_enum"`);
  }
}
