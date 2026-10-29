import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Codes for Jordanian numbers are now issued and checked by the backend
 * (AMS SMSC) instead of Twilio Verify, so wrong tries are counted here.
 */
export class OtpCodeAttempts1749200000000 implements MigrationInterface {
  name = 'OtpCodeAttempts1749200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE otp_codes ADD COLUMN IF NOT EXISTS attempts integer NOT NULL DEFAULT 0`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE otp_codes DROP COLUMN IF EXISTS attempts`,
    );
  }
}
