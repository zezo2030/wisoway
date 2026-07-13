import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePasswordResetSessions1746400000000
  implements MigrationInterface
{
  name = 'CreatePasswordResetSessions1746400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "password_reset_sessions" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "phoneNumber" varchar NOT NULL,
        "otpCode" varchar NOT NULL,
        "isVerified" boolean NOT NULL DEFAULT false,
        "attemptCount" integer NOT NULL DEFAULT 0,
        "isLocked" boolean NOT NULL DEFAULT false,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "expiresAt" TIMESTAMP NOT NULL,
        CONSTRAINT "PK_password_reset_sessions" PRIMARY KEY ("id")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_password_reset_phone"
      ON "password_reset_sessions" ("phoneNumber")
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_password_reset_expires"
      ON "password_reset_sessions" ("expiresAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "idx_password_reset_expires"`,
    );
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_password_reset_phone"`);
    await queryRunner.query(
      `DROP TABLE IF EXISTS "password_reset_sessions"`,
    );
  }
}
