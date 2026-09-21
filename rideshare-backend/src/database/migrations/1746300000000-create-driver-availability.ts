import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateDriverAvailability1746300000000 implements MigrationInterface {
  name = 'CreateDriverAvailability1746300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "driver_availability" (
        "driverId" uuid NOT NULL,
        "vehicleId" uuid,
        "isOnline" boolean NOT NULL DEFAULT false,
        "acceptsInstant" boolean NOT NULL DEFAULT true,
        "point" geography(Point,4326),
        "currentRequestId" uuid,
        "lastSeenAt" TIMESTAMP WITH TIME ZONE,
        "updatedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_driver_availability" PRIMARY KEY ("driverId"),
        CONSTRAINT "FK_driver_availability_driver" FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    // Partial spatial index: only online, unlocked drivers are ever matched,
    // so the index stays small and "available drivers near X" queries are fast.
    await queryRunner.query(`
      CREATE INDEX IF NOT EXISTS "driver_availability_available_point_idx"
      ON "driver_availability" USING GIST ("point")
      WHERE "isOnline" = true AND "currentRequestId" IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "driver_availability_available_point_idx"`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "driver_availability"`);
  }
}
