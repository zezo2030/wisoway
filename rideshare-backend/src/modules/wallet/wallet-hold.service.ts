import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import {
  WalletAccountEntity,
  WalletEntryDirection,
  WalletHoldEntity,
  WalletHoldStatus,
  WalletTransactionEntity,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { ErrorCodes } from '../../common/errors/error-codes';

export interface PlaceHoldParams {
  accountId: string;
  amount: number;
  referenceType: string;
  referenceId: string;
  metadata?: Record<string, unknown>;
  /** Optional — reuses an outer transaction when the caller already has one. */
  manager?: EntityManager;
}

export interface SettleHoldParams {
  referenceType: string;
  referenceId: string;
  /** Portion to take from the balance. Clamped to the hold amount. */
  captureAmount: number;
  metadata?: Record<string, unknown>;
  manager?: EntityManager;
}

export interface SettleHoldResult {
  hold: WalletHoldEntity;
  captured: number;
  released: number;
  currency: string;
  /** False when the hold was already settled — the call was a no-op replay. */
  applied: boolean;
}

/**
 * Reservation layer over `wallet_accounts`.
 *
 * `balance` is the money the account owns; `reservedBalance` is the part of it
 * promised to active holds. Spendable funds are `balance - reservedBalance`.
 *
 *   placeHold   → reservedBalance += amount        (balance untouched)
 *   captureHold → reservedBalance -= amount, balance -= captured
 *   releaseHold → reservedBalance -= amount        (balance untouched)
 *
 * Every mutation takes a `pessimistic_write` lock on the account row, so two
 * concurrent settlements for the same driver serialise rather than interleave.
 *
 * 012-passenger-presence-confirmation.
 */
@Injectable()
export class WalletHoldService {
  private readonly logger = new Logger(WalletHoldService.name);

  constructor(private readonly dataSource: DataSource) {}

  private round2(n: number): number {
    return Math.round(n * 100) / 100;
  }

  private run<T>(
    manager: EntityManager | undefined,
    fn: (m: EntityManager) => Promise<T>,
  ): Promise<T> {
    return manager ? fn(manager) : this.dataSource.transaction(fn);
  }

  async getActiveHold(
    referenceType: string,
    referenceId: string,
    manager?: EntityManager,
  ): Promise<WalletHoldEntity | null> {
    const repo = (manager ?? this.dataSource.manager).getRepository(
      WalletHoldEntity,
    );
    return repo.findOne({
      where: { referenceType, referenceId, status: WalletHoldStatus.ACTIVE },
    });
  }

  /**
   * Reserve `amount` against an account without moving the balance.
   *
   * Idempotent per (referenceType, referenceId): a second call while a hold is
   * still active returns the existing hold instead of double-reserving. The
   * partial unique index `uq_wallet_holds_active_reference` is the hard guard
   * behind this check.
   */
  async placeHold(params: PlaceHoldParams): Promise<WalletHoldEntity> {
    const amount = this.round2(params.amount);
    if (amount < 0) {
      throw new BadRequestException('Hold amount cannot be negative');
    }

    return this.run(params.manager, async (manager) => {
      const account = await manager.findOne(WalletAccountEntity, {
        where: { id: params.accountId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account) {
        throw new NotFoundException('Wallet account not found');
      }

      const existing = await manager.findOne(WalletHoldEntity, {
        where: {
          referenceType: params.referenceType,
          referenceId: params.referenceId,
          status: WalletHoldStatus.ACTIVE,
        },
      });
      if (existing) return existing;

      const balance = Number(account.balance);
      const reserved = Number(account.reservedBalance ?? 0);
      const available = this.round2(balance - reserved);
      if (available < amount) {
        throw new BadRequestException({
          statusCode: 400,
          code: ErrorCodes.INSUFFICIENT_AVAILABLE_BALANCE,
          message: 'Insufficient available wallet balance to activate trip',
          available: available.toFixed(2),
          required: amount.toFixed(2),
          currency: account.currency,
        });
      }

      account.reservedBalance = this.round2(reserved + amount).toFixed(2);
      await manager.save(account);

      const hold = await manager.save(
        manager.create(WalletHoldEntity, {
          accountId: account.id,
          amount: amount.toFixed(2),
          currency: account.currency,
          status: WalletHoldStatus.ACTIVE,
          referenceType: params.referenceType,
          referenceId: params.referenceId,
          metadata: params.metadata ?? null,
        }),
      );

      // Pending ledger row — becomes POSTED (at the captured amount) on capture,
      // or REVERSED on a full release.
      await manager.save(
        manager.create(WalletTransactionEntity, {
          accountId: account.id,
          type: WalletTransactionType.HOLD,
          direction: WalletEntryDirection.DEBIT,
          status: WalletTransactionStatus.PENDING,
          amount: amount.toFixed(2),
          currency: account.currency,
          referenceType: params.referenceType,
          referenceId: params.referenceId,
          metadata: { ...(params.metadata ?? {}), holdId: hold.id },
        }),
      );

      this.logger.log(
        `Hold ${hold.id} placed: ${amount.toFixed(2)} ${account.currency} on ${params.referenceType}:${params.referenceId}`,
      );
      return hold;
    });
  }

  /**
   * Close a hold: take `captureAmount` from the balance and return the rest.
   *
   * `captureAmount` is clamped to the held amount — if the fee basis grew after
   * the hold was placed (e.g. the trip's seat count was edited upward) we still
   * never take more than was reserved.
   *
   * Idempotent: settling an already-closed hold returns the recorded outcome
   * with `applied: false` and moves no money.
   */
  async settleHold(params: SettleHoldParams): Promise<SettleHoldResult> {
    return this.run(params.manager, async (manager) => {
      const hold = await manager.findOne(WalletHoldEntity, {
        where: {
          referenceType: params.referenceType,
          referenceId: params.referenceId,
        },
        order: { createdAt: 'DESC' },
      });
      if (!hold) {
        throw new NotFoundException({
          statusCode: 404,
          code: ErrorCodes.HOLD_NOT_FOUND,
          message: `No wallet hold for ${params.referenceType}:${params.referenceId}`,
        });
      }

      if (hold.status !== WalletHoldStatus.ACTIVE) {
        return {
          hold,
          captured: Number(hold.capturedAmount ?? 0),
          released: Number(hold.releasedAmount ?? 0),
          currency: hold.currency,
          applied: false,
        };
      }

      const account = await manager.findOne(WalletAccountEntity, {
        where: { id: hold.accountId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account) {
        throw new NotFoundException('Wallet account not found');
      }

      const held = Number(hold.amount);
      const captured = this.round2(
        Math.min(Math.max(params.captureAmount, 0), held),
      );
      const released = this.round2(held - captured);

      account.reservedBalance = this.round2(
        Math.max(Number(account.reservedBalance ?? 0) - held, 0),
      ).toFixed(2);
      account.balance = this.round2(Number(account.balance) - captured).toFixed(
        2,
      );
      await manager.save(account);

      hold.status = captured > 0
        ? WalletHoldStatus.CAPTURED
        : WalletHoldStatus.RELEASED;
      hold.capturedAmount = captured.toFixed(2);
      hold.releasedAmount = released.toFixed(2);
      hold.settledAt = new Date();
      hold.metadata = { ...(hold.metadata ?? {}), ...(params.metadata ?? {}) };
      await manager.save(hold);

      // Resolve the pending HOLD row to what was actually taken.
      const pending = await manager.findOne(WalletTransactionEntity, {
        where: {
          referenceType: params.referenceType,
          referenceId: params.referenceId,
          type: WalletTransactionType.HOLD,
          status: WalletTransactionStatus.PENDING,
        },
        order: { createdAt: 'DESC' },
      });
      if (pending) {
        pending.amount = captured.toFixed(2);
        pending.status = captured > 0
          ? WalletTransactionStatus.POSTED
          : WalletTransactionStatus.REVERSED;
        pending.metadata = {
          ...((pending.metadata as Record<string, unknown>) ?? {}),
          ...(params.metadata ?? {}),
          heldAmount: held.toFixed(2),
          releasedAmount: released.toFixed(2),
        };
        await manager.save(pending);
      }

      if (released > 0) {
        await manager.save(
          manager.create(WalletTransactionEntity, {
            accountId: account.id,
            type: WalletTransactionType.RELEASE_HOLD,
            direction: WalletEntryDirection.CREDIT,
            status: WalletTransactionStatus.POSTED,
            amount: released.toFixed(2),
            currency: account.currency,
            referenceType: params.referenceType,
            referenceId: params.referenceId,
            metadata: {
              ...(params.metadata ?? {}),
              holdId: hold.id,
              heldAmount: held.toFixed(2),
              capturedAmount: captured.toFixed(2),
            },
          }),
        );
      }

      this.logger.log(
        `Hold ${hold.id} settled: captured ${captured.toFixed(2)}, released ${released.toFixed(2)} ${hold.currency}`,
      );

      return {
        hold,
        captured,
        released,
        currency: hold.currency,
        applied: true,
      };
    });
  }

  /** Convenience wrapper — settle with nothing captured (cancellation path). */
  async releaseHold(
    referenceType: string,
    referenceId: string,
    metadata?: Record<string, unknown>,
    manager?: EntityManager,
  ): Promise<SettleHoldResult | null> {
    const active = await this.getActiveHold(
      referenceType,
      referenceId,
      manager,
    );
    if (!active) return null;
    return this.settleHold({
      referenceType,
      referenceId,
      captureAmount: 0,
      metadata,
      manager,
    });
  }
}
