import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * The exact spot a shared trip gathers at — a map pin plus the driver's
 * description ("by the roundabout, in front of the pharmacy") — so driver and
 * passengers agree on one place instead of reading it off the trip's origin
 * area. Shape: { lat, lng, address?, note? }; null on older trips.
 */
export class AddTripMeetingPoint1747800000000 implements MigrationInterface {
  name = 'AddTripMeetingPoint1747800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "meetingPoint" jsonb`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trips" DROP COLUMN IF EXISTS "meetingPoint"`,
    );
  }
}
