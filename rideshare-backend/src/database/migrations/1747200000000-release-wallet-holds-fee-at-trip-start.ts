import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Fee-at-trip-start cutover.
 *
 * The hold mechanism is gone (`WalletHoldService` was deleted in the previous
 * commit), so every hold that is still open would otherwise strand a driver's
 * money in `wallet_accounts."reservedBalance"` with no code left able to
 * release it. This migration returns the reservation and closes the row.
 *
 * Pure SQL on purpose: it has to run after the service that used to do this
 * work no longer exists.
 *
 * Predicate note — the open-hold test is `status NOT IN ('captured',
 * 'released')`, not `status = 'active'`. `wallet_holds."status"` is a plain
 * varchar whose database DEFAULT is `'pending'`, a value the `WalletHoldStatus`
 * constant never defines. A row inserted without an explicit status therefore
 * sits at `'pending'`, and an `= 'active'` predicate would skip it and strand
 * that driver's reservation forever. Inverting the test makes the only excluded
 * rows the genuinely terminal ones, which is the sole case we must not touch.
 *
 * Money-safety invariant this rests on: an open hold only ever moved
 * `reservedBalance`; `balance` moved exclusively at capture time
 * (`WalletHoldService.settleHold`). So returning a reservation means zeroing
 * `reservedBalance` and nothing else — `balance` is deliberately untouched.
 *
 * Trips that already had their fee captured under the old presence-settlement
 * model are stamped `driverWalletChargeApplied = true` so the new trip-start
 * debit (`DriverTripFeeService`, which short-circuits on that stamp) can never
 * charge them a second time.
 */
export class ReleaseWalletHoldsFeeAtTripStart1747200000000
  implements MigrationInterface
{
  name = 'ReleaseWalletHoldsFeeAtTripStart1747200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Give back every reservation still sitting on an account. Nothing reads
    //    `reservedBalance` any more, so zeroing it wholesale is what guarantees
    //    no driver is left with money reserved against a hold row that drifted
    //    out of sync. `balance` is not touched — see the invariant above.
    await queryRunner.query(`
      UPDATE "wallet_accounts"
      SET "reservedBalance" = '0.00'
      WHERE "reservedBalance" IS DISTINCT FROM 0
    `);

    // 2. Close the open holds with an audit note, mirroring what a full release
    //    through settleHold() would have written.
    await queryRunner.query(`
      UPDATE "wallet_holds"
      SET "status" = 'released',
          "releasedAmount" = "amount",
          "capturedAmount" = '0.00',
          "settledAt" = COALESCE("settledAt", now()),
          "metadata" = COALESCE("metadata", '{}'::jsonb)
                       || '{"migration":"fee-at-trip-start"}'::jsonb
      WHERE "status" NOT IN ('captured', 'released')
    `);

    // 3. Reverse the pending ledger rows those holds created. placeHold() wrote
    //    a PENDING/HOLD row per reservation; settleHold() resolved it to POSTED
    //    or REVERSED. A full release is the REVERSED branch.
    await queryRunner.query(`
      UPDATE "wallet_transactions"
      SET "status" = 'reversed'
      WHERE "type" = 'hold' AND "status" = 'pending'
    `);

    // 4. Any trip already settled under the old presence-capture model keeps
    //    that charge and is stamped so the new trip-start debit skips it.
    //    `driverWalletChargeApplied` is nullable in the database, so the guard
    //    is `IS NOT TRUE` rather than `= false`.
    await queryRunner.query(`
      UPDATE "trips"
      SET "driverWalletChargeApplied" = true
      WHERE "presenceSettledAt" IS NOT NULL
        AND "driverWalletChargeApplied" IS NOT TRUE
    `);
  }

  public async down(): Promise<void> {
    // Intentional no-op. Releasing money to drivers is not reversible by
    // migration — re-reserving funds a driver may already have spent would
    // create negative spendable balances, and the hold code able to manage
    // those reservations no longer exists. Restore from a backup if this
    // cutover has to be undone.
  }
}
