/**
 * PendingChargesService
 *
 * Manages monetary penalty charges that are either collected immediately from
 * a user's wallet or carried forward to the next booking confirmation.
 *
 * Phase 4 / T074–T075 — 008-platform-completion, US2 / 010-booking-lifecycle.
 */
import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import {
  PendingChargeEntity,
  PendingChargeKind,
  PendingChargeStatus,
} from '../../database/entities/pending-charge.entity';
import {
  WalletAccountEntity,
  WalletTransactionEntity,
  WalletAccountType,
  WalletEntryDirection,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { PaginatedResult } from '../../common/interfaces/paginated-result.interface';
import {
  pickPrimaryWalletLedgerAccount,
  WalletService,
} from '../wallet/wallet.service';

function walletAccountTypeForCharge(
  kind: PendingChargeKind,
): WalletAccountType {
  return kind === PendingChargeKind.DRIVER_NO_SHOW
    ? WalletAccountType.DRIVER
    : WalletAccountType.RIDER;
}

export interface RecordChargeParams {
  userId: string;
  kind: PendingChargeKind;
  amount: number;
  bookingId?: string | null;
  tripId?: string | null;
}

export interface CollectResult {
  applied: PendingChargeEntity[];
  skipped: PendingChargeEntity[];
}

@Injectable()
export class PendingChargesService {
  private readonly logger = new Logger(PendingChargesService.name);

  constructor(
    @InjectRepository(PendingChargeEntity)
    private chargeRepo: Repository<PendingChargeEntity>,
    @InjectRepository(WalletAccountEntity)
    private walletAccountRepo: Repository<WalletAccountEntity>,
    @InjectRepository(WalletTransactionEntity)
    private walletTxRepo: Repository<WalletTransactionEntity>,
    private dataSource: DataSource,
    private readonly walletService: WalletService,
  ) {}

  // ── T074: record ──────────────────────────────────────────────────────────

  /**
   * Record a new pending charge.  Tries to deduct from the user's wallet
   * immediately; if the wallet has insufficient balance the charge is left
   * in PENDING status for collection at the next booking confirmation.
   */
  async record(params: RecordChargeParams): Promise<PendingChargeEntity> {
    const { userId, kind, amount, bookingId = null, tripId = null } = params;

    const charge = this.chargeRepo.create({
      userId,
      kind,
      amount: amount.toFixed(2),
      status: PendingChargeStatus.PENDING,
      bookingId,
      tripId,
    });
    const saved = await this.chargeRepo.save(charge);

    // Attempt immediate collection
    try {
      const result = await this.deductFromWallet(
        userId,
        amount,
        saved.id,
        kind,
      );
      if (result) {
        saved.status = PendingChargeStatus.APPLIED;
        saved.walletTransactionId = result.id;
        await this.chargeRepo.save(saved);
        this.logger.log(
          `Pending charge ${saved.id} collected immediately (tx ${result.id})`,
        );
      }
    } catch (err) {
      this.logger.warn(
        `Immediate collection failed for charge ${saved.id}: ${(err as Error).message} — will carry forward`,
      );
    }

    return saved;
  }

  // ── T075: collectOutstanding ──────────────────────────────────────────────

  /**
   * Sweep all PENDING charges for a user and attempt wallet deduction for each.
   * Called at booking confirmation time (before the booking is confirmed).
   *
   * @param userId            The user whose outstanding charges should be swept.
   * @param triggeringBookingId  The booking confirmation that triggered this sweep.
   */
  async collectOutstanding(
    userId: string,
    triggeringBookingId: string | null,
  ): Promise<CollectResult> {
    const charges = await this.chargeRepo.find({
      where: { userId, status: PendingChargeStatus.PENDING },
      order: { createdAt: 'ASC' },
    });

    const applied: PendingChargeEntity[] = [];
    const skipped: PendingChargeEntity[] = [];

    for (const charge of charges) {
      try {
        const tx = await this.deductFromWallet(
          userId,
          Number(charge.amount),
          charge.id,
          charge.kind,
        );
        if (tx) {
          charge.status = PendingChargeStatus.APPLIED;
          charge.walletTransactionId = tx.id;
          charge.appliedToBookingId = triggeringBookingId;
          await this.chargeRepo.save(charge);
          applied.push(charge);
          this.logger.log(
            `Pending charge ${charge.id} collected at booking ${triggeringBookingId} (tx ${tx.id})`,
          );
        } else {
          skipped.push(charge);
        }
      } catch (err) {
        this.logger.warn(
          `Collection of charge ${charge.id} failed: ${(err as Error).message} — skipped`,
        );
        skipped.push(charge);
      }
    }

    return { applied, skipped };
  }

  // ── T076: findByUser ──────────────────────────────────────────────────────

  async findByUser(
    userId: string,
    options: { page: number; limit: number; status?: PendingChargeStatus },
  ): Promise<PaginatedResult<PendingChargeEntity>> {
    const { page = 1, limit = 20, status } = options;
    const skip = (page - 1) * limit;

    const qb = this.chargeRepo
      .createQueryBuilder('pc')
      .where('pc.userId = :userId', { userId })
      .orderBy('pc.createdAt', 'DESC');

    if (status) qb.andWhere('pc.status = :status', { status });

    const [data, total] = await Promise.all([
      qb.skip(skip).take(limit).getMany(),
      qb.clone().getCount(),
    ]);

    return {
      data,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  /**
   * Summary of a user's outstanding (PENDING) charges. Used as a gate before
   * actions like driver trip creation — drivers with unsettled penalties must
   * clear them (top up wallet, or admin waiver) before publishing again.
   */
  async getOutstandingSummary(
    userId: string,
  ): Promise<{ count: number; totalAmount: number }> {
    const charges = await this.chargeRepo.find({
      where: { userId, status: PendingChargeStatus.PENDING },
      select: ['id', 'amount'],
    });
    const totalAmount = charges.reduce(
      (sum, c) => sum + Number(c.amount ?? 0),
      0,
    );
    return { count: charges.length, totalAmount };
  }

  // ── T077: waive ───────────────────────────────────────────────────────────

  async waive(chargeId: string, adminId: string): Promise<PendingChargeEntity> {
    const charge = await this.chargeRepo.findOne({ where: { id: chargeId } });
    if (!charge) throw new NotFoundException('Pending charge not found');
    if (charge.status !== PendingChargeStatus.PENDING) {
      throw new BadRequestException(
        `Charge is already ${charge.status} and cannot be waived`,
      );
    }
    charge.status = PendingChargeStatus.WAIVED;
    charge.waivedByAdminId = adminId;
    charge.waivedAt = new Date();
    return this.chargeRepo.save(charge);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /**
   * Attempt to deduct `amount` from the user's wallet — DRIVER wallet for
   * driver_no_show charges, RIDER wallet for passenger charges. Returns the
   * created WalletTransactionEntity on success, or null if the wallet balance
   * is insufficient (no exception — caller decides).
   */
  private async deductFromWallet(
    userId: string,
    amount: number,
    chargeId: string,
    kind: PendingChargeKind,
  ): Promise<WalletTransactionEntity | null> {
    const accountType = walletAccountTypeForCharge(kind);
    return this.dataSource.transaction(async (manager) => {
      const lockedRows = await manager
        .createQueryBuilder(WalletAccountEntity, 'wa')
        .setLock('pessimistic_write')
        .where('wa.userId = :userId', { userId })
        .andWhere('wa.accountType = :accountType', { accountType })
        .orderBy('wa.id', 'ASC')
        .getMany();

      if (lockedRows.length === 0) {
        const created = manager.create(WalletAccountEntity, {
          userId,
          accountType,
          currency: 'JOD',
          balance: '0.00',
          isActive: true,
        });
        await manager.save(WalletAccountEntity, created);
        return null;
      }

      const account = pickPrimaryWalletLedgerAccount(lockedRows);
      if (!account) return null;

      const current = Number(account.balance);
      if (current < amount) return null;

      account.balance = (current - amount).toFixed(2);
      await manager.save(WalletAccountEntity, account);

      const tx = manager.create(WalletTransactionEntity, {
        accountId: account.id,
        type: WalletTransactionType.ADJUSTMENT,
        direction: WalletEntryDirection.DEBIT,
        status: WalletTransactionStatus.POSTED,
        amount: amount.toFixed(2),
        currency: account.currency,
        referenceType: 'pending_charge',
        referenceId: chargeId,
      });
      const saved = await manager.save(WalletTransactionEntity, tx);
      await this.walletService.syncUserLegacyWalletMirror(
        userId,
        accountType,
        manager,
      );
      return saved;
    });
  }
}
