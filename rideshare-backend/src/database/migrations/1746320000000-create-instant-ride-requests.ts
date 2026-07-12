import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateInstantRideRequests1746320000000 implements MigrationInterface {
  name = 'CreateInstantRideRequests1746320000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "instant_ride_requests" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "passengerId" uuid NOT NULL,
        "fromName" varchar(160) NOT NULL,
        "fromAddress" text,
        "fromPoint" geography(Point,4326) NOT NULL,
        "toName" varchar(160) NOT NULL,
        "toAddress" text,
        "toPoint" geography(Point,4326) NOT NULL,
        "seatCount" integer NOT NULL DEFAULT 1,
        "status" varchar(16) NOT NULL DEFAULT 'searching',
        "fareEstimate" numeric(10,2),
        "currency" varchar(5) NOT NULL DEFAULT 'JOD',
        "radiusKm" double precision NOT NULL DEFAULT 3,
        "matchedDriverId" uuid,
        "tripId" uuid,
        "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_instant_ride_requests" PRIMARY KEY ("id"),
        CONSTRAINT "FK_instant_requests_passenger" FOREIGN KEY ("passengerId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "instant_requests_passenger_status_idx"
      ON "instant_ride_requests" ("passengerId", "status")
    `);
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "instant_requests_from_point_idx"
      ON "instant_ride_requests" USING GIST ("fromPoint")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "instant_requests_from_point_idx"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "instant_requests_passenger_status_idx"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "instant_ride_requests"`);
  }
}
