import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Only passengers may hide their phone number: a passenger must always be
 * able to call their driver. Clears the flag drivers had switched on.
 */
export class DriversShowPhone1749400000000 implements MigrationInterface {
  name = 'DriversShowPhone1749400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `UPDATE users SET "hidePhoneNumber" = false WHERE role = 'driver' AND "hidePhoneNumber" = true`,
    );
  }

  public async down(): Promise<void> {
    // Which drivers had hidden their number is not kept.
  }
}
