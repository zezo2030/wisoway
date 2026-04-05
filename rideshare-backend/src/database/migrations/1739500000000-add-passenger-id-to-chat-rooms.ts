import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPassengerIdToChatRooms1739500000000 implements MigrationInterface {
  name = 'AddPassengerIdToChatRooms1739500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE chat_rooms
      ADD COLUMN IF NOT EXISTS "passengerId" UUID REFERENCES users(id) ON DELETE CASCADE
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_trip_passenger
      ON chat_rooms ("tripId", "passengerId")
      WHERE "passengerId" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS idx_chat_rooms_trip_passenger`,
    );
    await queryRunner.query(
      `ALTER TABLE chat_rooms DROP COLUMN IF EXISTS "passengerId"`,
    );
  }
}
