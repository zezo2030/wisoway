import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUsersMissingColumns1738800000000 implements MigrationInterface {
  name = 'AddUsersMissingColumns1738800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS gender VARCHAR,
        ADD COLUMN IF NOT EXISTS "photoUrl" TEXT,
        ADD COLUMN IF NOT EXISTS provider VARCHAR DEFAULT 'email',
        ADD COLUMN IF NOT EXISTS "providerId" VARCHAR,
        ADD COLUMN IF NOT EXISTS rating DECIMAL(3,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "totalRatings" INT DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "isPhoneVerified" BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS "isEmailVerified" BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS "isDriverApproved" BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS "refreshToken" VARCHAR,
        ADD COLUMN IF NOT EXISTS "walletBalance" DECIMAL(10,2) DEFAULT 0,
        ADD COLUMN IF NOT EXISTS "walletCurrency" VARCHAR(5) DEFAULT 'EGP',
        ADD COLUMN IF NOT EXISTS "hasUsedLifetimeFreeTrip" BOOLEAN DEFAULT FALSE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE users
        DROP COLUMN IF EXISTS gender,
        DROP COLUMN IF EXISTS "photoUrl",
        DROP COLUMN IF EXISTS provider,
        DROP COLUMN IF EXISTS "providerId",
        DROP COLUMN IF EXISTS rating,
        DROP COLUMN IF EXISTS "totalRatings",
        DROP COLUMN IF EXISTS "isPhoneVerified",
        DROP COLUMN IF EXISTS "isEmailVerified",
        DROP COLUMN IF EXISTS "isDriverApproved",
        DROP COLUMN IF EXISTS "refreshToken",
        DROP COLUMN IF EXISTS "walletBalance",
        DROP COLUMN IF EXISTS "walletCurrency",
        DROP COLUMN IF EXISTS "hasUsedLifetimeFreeTrip"
    `);
  }
}
