import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPassengerReportedDriverAbsentToBookings1745931000000 implements MigrationInterface {
  name = 'AddPassengerReportedDriverAbsentToBookings1745931000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" ADD COLUMN IF NOT EXISTS "passengerReportedDriverAbsentAt" TIMESTAMP NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "bookings" DROP COLUMN IF EXISTS "passengerReportedDriverAbsentAt"`,
    );
  }
}
