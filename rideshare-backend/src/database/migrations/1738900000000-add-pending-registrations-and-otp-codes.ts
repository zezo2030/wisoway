import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPendingRegistrationsAndOtpCodes1738900000000 implements MigrationInterface {
  name = 'AddPendingRegistrationsAndOtpCodes1738900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pending_registration_gender_enum') THEN
          CREATE TYPE pending_registration_gender_enum AS ENUM ('male', 'female');
        END IF;
      END$$;
    `);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS pending_registrations (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "phoneNumber" VARCHAR NOT NULL UNIQUE,
        email VARCHAR UNIQUE,
        "passwordHash" VARCHAR NOT NULL,
        name VARCHAR(100) NOT NULL,
        gender pending_registration_gender_enum,
        role users_role_enum NOT NULL DEFAULT 'passenger',
        "expiresAt" TIMESTAMPTZ NOT NULL,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_pending_registration_phone ON pending_registrations ("phoneNumber")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_pending_registration_email ON pending_registrations (email)`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS otp_codes (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "phoneNumber" VARCHAR NOT NULL,
        code VARCHAR(6) NOT NULL,
        "expiresAt" TIMESTAMPTZ NOT NULL,
        "isUsed" BOOLEAN NOT NULL DEFAULT FALSE,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_otp_codes_phone_code ON otp_codes ("phoneNumber", code)`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_otp_codes_expires_at ON otp_codes ("expiresAt")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS otp_codes`);
    await queryRunner.query(`DROP TABLE IF EXISTS pending_registrations`);
    await queryRunner.query(
      `DROP TYPE IF EXISTS pending_registration_gender_enum`,
    );
  }
}
