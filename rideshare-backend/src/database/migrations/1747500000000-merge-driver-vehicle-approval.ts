import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Merged driver review: `users.isDriverApproved` and `vehicles.isVerified`
 * now represent a single decision and must never diverge.
 *
 * Corrective pass over existing data using the optimistic union: a driver
 * (or vehicle) that passed any prior admin review keeps that approval.
 */
export class MergeDriverVehicleApproval1747500000000
  implements MigrationInterface
{
  name = 'MergeDriverVehicleApproval1747500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Approved driver with unverified vehicle -> verify the vehicle.
    await queryRunner.query(`
      UPDATE vehicles v
      SET "isVerified" = true, "updatedAt" = NOW()
      FROM users u
      WHERE v."driverId" = u.id
        AND u.role = 'driver'
        AND u."isDriverApproved" = true
        AND v."isVerified" = false
    `);

    // Verified vehicle with unapproved driver -> approve the driver.
    await queryRunner.query(`
      UPDATE users u
      SET "isDriverApproved" = true, "updatedAt" = NOW()
      FROM vehicles v
      WHERE v."driverId" = u.id
        AND u.role = 'driver'
        AND u."isDriverApproved" = false
        AND v."isVerified" = true
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Cannot reconstruct which side was reviewed first; no-op.
    void queryRunner;
  }
}
