import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCommunicationFeesTable1739400000000 implements MigrationInterface {
  name = 'AddCommunicationFeesTable1739400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS communication_fees (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "countryCode" VARCHAR(5) NOT NULL,
        "feeAmount" DECIMAL(10,2) NOT NULL,
        currency VARCHAR(5) NOT NULL,
        "isActive" BOOLEAN NOT NULL DEFAULT TRUE,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT idx_communication_fees_country UNIQUE ("countryCode")
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS communication_fees`);
  }
}
