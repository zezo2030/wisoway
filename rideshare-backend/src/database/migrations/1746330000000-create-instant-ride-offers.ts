import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateInstantRideOffers1746330000000 implements MigrationInterface {
  name = 'CreateInstantRideOffers1746330000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "instant_ride_offers" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "requestId" uuid NOT NULL,
        "driverId" uuid NOT NULL,
        "vehicleId" uuid,
        "status" varchar(16) NOT NULL DEFAULT 'offered',
        "offeredAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "respondedAt" TIMESTAMP WITH TIME ZONE,
        "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_instant_ride_offers" PRIMARY KEY ("id"),
        CONSTRAINT "FK_instant_offers_request" FOREIGN KEY ("requestId") REFERENCES "instant_ride_requests"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_instant_offers_driver" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "instant_offers_request_idx"
      ON "instant_ride_offers" ("requestId")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "instant_offers_driver_status_idx"
      ON "instant_ride_offers" ("driverId", "status")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "instant_offers_driver_status_idx"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "instant_offers_request_idx"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "instant_ride_offers"`);
  }
}
