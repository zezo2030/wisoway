import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Terminal-state metadata + retry audit trail for instant requests:
 * - `terminalReason`/`endedAt`: why and when searching stopped, so the
 *   passenger's "no driver found" screen can explain itself.
 * - `retryOfRequestId`: links a new attempt to the exhausted one. The partial
 *   unique index makes a double-tapped retry idempotent at the database level.
 * - `instant_requests_searching_per_passenger_idx`: one live search per
 *   passenger, enforced in the database rather than by an application check.
 *   Only `searching`/`offered` are covered: `accepted` rows stay accepted for
 *   the life of the trip and are guarded by the service-level check instead.
 */
export class AddInstantTerminalRetryMetadata1746520000000 implements MigrationInterface {
  name = 'AddInstantTerminalRetryMetadata1746520000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      ADD COLUMN IF NOT EXISTS "terminalReason" varchar(32),
      ADD COLUMN IF NOT EXISTS "endedAt" timestamptz,
      ADD COLUMN IF NOT EXISTS "retryOfRequestId" uuid
    `);

    await queryRunner.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'FK_instant_requests_retry_of'
        ) THEN
          ALTER TABLE "instant_ride_requests"
          ADD CONSTRAINT "FK_instant_requests_retry_of"
          FOREIGN KEY ("retryOfRequestId")
          REFERENCES "instant_ride_requests"("id") ON DELETE SET NULL;
        END IF;
      END $$
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "instant_requests_retry_of_uniq"
      ON "instant_ride_requests" ("retryOfRequestId")
      WHERE "retryOfRequestId" IS NOT NULL
    `);

    // Close out searches whose window already elapsed, then keep only the
    // newest live search per passenger, so the unique index can be created on
    // pre-existing data.
    await queryRunner.query(`
      UPDATE "instant_ride_requests"
      SET "status" = 'expired',
          "terminalReason" = 'ttl_expired',
          "endedAt" = COALESCE("endedAt", "expiresAt")
      WHERE "status" IN ('searching', 'offered')
        AND "expiresAt" <= now()
    `);
    await queryRunner.query(`
      UPDATE "instant_ride_requests" r
      SET "status" = 'expired',
          "terminalReason" = 'ttl_expired',
          "endedAt" = COALESCE(r."endedAt", now())
      WHERE r."status" IN ('searching', 'offered')
        AND EXISTS (
          SELECT 1 FROM "instant_ride_requests" newer
          WHERE newer."passengerId" = r."passengerId"
            AND newer."status" IN ('searching', 'offered')
            AND (newer."createdAt", newer."id") > (r."createdAt", r."id")
        )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "instant_requests_searching_per_passenger_idx"
      ON "instant_ride_requests" ("passengerId")
      WHERE "status" IN ('searching', 'offered')
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DROP INDEX IF EXISTS "instant_requests_searching_per_passenger_idx"
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS "instant_requests_retry_of_uniq"
    `);
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      DROP CONSTRAINT IF EXISTS "FK_instant_requests_retry_of"
    `);
    await queryRunner.query(`
      ALTER TABLE "instant_ride_requests"
      DROP COLUMN IF EXISTS "terminalReason",
      DROP COLUMN IF EXISTS "endedAt",
      DROP COLUMN IF EXISTS "retryOfRequestId"
    `);
  }
}
