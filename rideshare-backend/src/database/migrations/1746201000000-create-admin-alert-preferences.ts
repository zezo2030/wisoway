import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateAdminAlertPreferences1746201000000 implements MigrationInterface {
  name = 'CreateAdminAlertPreferences1746201000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'admin_alert_preference_alerttype_enum') THEN
          CREATE TYPE "admin_alert_preference_alerttype_enum" AS ENUM ('driver_registration', 'fee_payment');
        END IF;
      END $$;
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "admin_alert_preference" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "userId" uuid NOT NULL,
        "alertType" "admin_alert_preference_alerttype_enum" NOT NULL,
        "enabled" boolean NOT NULL DEFAULT true,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_admin_alert_preference" PRIMARY KEY ("id"),
        CONSTRAINT "admin_alert_preference_user_type_unique" UNIQUE ("userId", "alertType"),
        CONSTRAINT "FK_admin_alert_preference_user" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "admin_alert_preference_user_idx"
      ON "admin_alert_preference" ("userId")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "admin_alert_preference_user_idx"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "admin_alert_preference"`);
    await queryRunner.query(
      `DROP TYPE IF EXISTS "admin_alert_preference_alerttype_enum"`,
    );
  }
}
