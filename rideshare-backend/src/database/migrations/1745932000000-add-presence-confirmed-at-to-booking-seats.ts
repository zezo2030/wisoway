import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddPresenceConfirmedAtToBookingSeats1745932000000 implements MigrationInterface {
  name = 'AddPresenceConfirmedAtToBookingSeats1745932000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "booking_seats" ADD COLUMN IF NOT EXISTS "presenceConfirmedAt" TIMESTAMP NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "booking_seats" DROP COLUMN IF EXISTS "presenceConfirmedAt"`,
    );
  }
}
