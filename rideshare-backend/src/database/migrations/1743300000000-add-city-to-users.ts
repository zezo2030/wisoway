import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCityToUsers1743300000000 implements MigrationInterface {
  name = 'AddCityToUsers1743300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS "city" VARCHAR(64) NULL
    `);

    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "idx_users_lower_city"
        ON users (LOWER(city))
        WHERE "isActive" = true
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_users_lower_city"`);
    await queryRunner.query(`ALTER TABLE users DROP COLUMN IF EXISTS "city"`);
  }
}
