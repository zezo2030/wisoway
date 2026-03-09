import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddChatRoomsAndMessages1739300000000 implements MigrationInterface {
  name = 'AddChatRoomsAndMessages1739300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS chat_rooms (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "tripId" UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        participants JSONB NOT NULL DEFAULT '[]',
        "lastMessage" TEXT,
        "lastMessageTime" TIMESTAMPTZ,
        "lastMessageSenderId" UUID REFERENCES users(id) ON DELETE SET NULL,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_chat_rooms_trip_id ON chat_rooms ("tripId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_chat_rooms_last_message_time ON chat_rooms ("lastMessageTime")`,
    );

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        "chatRoomId" UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
        "senderId" UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        "senderName" VARCHAR,
        text TEXT NOT NULL,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_messages_chat_room ON messages ("chatRoomId")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_messages_created_at_desc ON messages ("chatRoomId", "createdAt" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS messages`);
    await queryRunner.query(`DROP TABLE IF EXISTS chat_rooms`);
  }
}
