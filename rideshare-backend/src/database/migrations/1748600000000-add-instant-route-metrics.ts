import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * The route distance / duration a request's fare was priced on. The search
 * sheet and the offer card showed a straight line at city speed instead
 * (AlUla → Tabuk: 236 km and 9½ hours, against ~296 km and 3½ hours by road).
 */
export class AddInstantRouteMetrics1748600000000 implements MigrationInterface {
  name = 'AddInstantRouteMetrics1748600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "routeDistanceKm" DOUBLE PRECISION NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" ADD COLUMN IF NOT EXISTS "routeDurationMinutes" INT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "routeDurationMinutes"`,
    );
    await queryRunner.query(
      `ALTER TABLE "instant_ride_requests" DROP COLUMN IF EXISTS "routeDistanceKm"`,
    );
  }
}
