import { MigrationInterface, QueryRunner } from 'typeorm';

export class TripAuthoring08RecurrenceStopsNotes1745908000000 implements MigrationInterface {
  name = 'TripAuthoring08RecurrenceStopsNotes1745908000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "trip_recurrence_rules" (
        "id" UUID NOT NULL DEFAULT gen_random_uuid(),
        "driverId" UUID NOT NULL,
        "templateJson" JSONB NOT NULL,
        "frequency" VARCHAR(10) NOT NULL CHECK ("frequency" IN ('daily','weekly')),
        "weekdayMask" SMALLINT NOT NULL DEFAULT 0,
        "localTime" TIME NOT NULL,
        "timezone" VARCHAR(40) NOT NULL DEFAULT 'Asia/Amman',
        "until" DATE,
        "lastSpawnedFor" DATE,
        "isActive" BOOLEAN NOT NULL DEFAULT true,
        "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_trip_recurrence_rules" PRIMARY KEY ("id"),
        CONSTRAINT "FK_trip_recurrence_rules_driver" FOREIGN KEY ("driverId")
          REFERENCES "users"("id") ON DELETE CASCADE
      );
    `);

    await queryRunner.query(`
      CREATE INDEX "recurrence_rules_driver_active_idx"
        ON "trip_recurrence_rules" ("driverId", "isActive");
    `);

    await queryRunner.query(`
      CREATE INDEX "recurrence_rules_spawn_sweep_idx"
        ON "trip_recurrence_rules" ("isActive", "lastSpawnedFor");
    `);

    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD COLUMN IF NOT EXISTS "recurrenceRuleId" UUID NULL;
    `);

    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD CONSTRAINT "FK_trips_recurrence_rule"
        FOREIGN KEY ("recurrenceRuleId")
        REFERENCES "trip_recurrence_rules"("id") ON DELETE SET NULL;
    `);

    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD COLUMN IF NOT EXISTS "stops" JSONB NOT NULL DEFAULT '[]';
    `);

    await queryRunner.query(`
      ALTER TABLE "trips"
        ADD COLUMN IF NOT EXISTS "notes" TEXT NULL;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "notes";`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "stops";`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" DROP CONSTRAINT IF EXISTS "FK_trips_recurrence_rule";`,
    );
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "recurrenceRuleId";`,
    );
    await queryRunner.query(`DROP TABLE IF EXISTS "trip_recurrence_rules";`);
  }
}
