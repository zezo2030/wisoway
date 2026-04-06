import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, In, Repository } from 'typeorm';
import {
  PayoutRequestEntity,
  TripEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletEntryDirection,
  PayoutStatus,
  WalletTransactionEntity,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { CreateTopupDto } from './dto/create-topup.dto';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';
import { DriverTripChargeDto } from './dto/driver-trip-charge.dto';

@Injectable()
export class WalletService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(WalletAccountEntity)
    private readonly walletAccountRepo: Repository<WalletAccountEntity>,
    @InjectRepository(WalletTransactionEntity)
    private readonly walletTxRepo: Repository<WalletTransactionEntity>,
    @InjectRepository(PayoutRequestEntity)
    private readonly payoutRepo: Repository<PayoutRequestEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
  ) {}

  /** Avoid duplicate rows that differ only by currency casing (JOD vs jod). */
  private normalizeWalletCurrency(currency?: string | null): string {
    const c = (currency ?? 'JOD').trim();
    return c.length > 0 ? c.toUpperCase() : 'JOD';
  }

  private async getOrCreateAccount(
    userId: string,
    accountType: WalletAccountType,
    currency = 'JOD',
  ) {
    const c = this.normalizeWalletCurrency(currency);
    let account = await this.walletAccountRepo.findOne({
      where: { userId, accountType, currency: c },
    });
    if (!account) {
      account = this.walletAccountRepo.create({
        userId,
        accountType,
        currency: c,
        balance: '0',
        isActive: true,
      });
      account = await this.walletAccountRepo.save(account);
    }
    return account;
  }

  private async getOrCreateAccountWithManager(
    manager: EntityManager,
    userId: string,
    accountType: WalletAccountType,
    currency = 'JOD',
  ): Promise<WalletAccountEntity> {
    const c = this.normalizeWalletCurrency(currency);
    let account = await manager.findOne(WalletAccountEntity, {
      where: { userId, accountType, currency: c },
    });
    if (!account) {
      account = manager.create(WalletAccountEntity, {
        userId,
        accountType,
        currency: c,
        balance: '0',
        isActive: true,
      });
      account = await manager.save(account);
    }
    return account;
  }

  /**
   * Debits the driver's Postgres wallet (same ledger as top-ups). Idempotent per trip.
   * Call inside an outer transaction [EntityManager] so it commits with trip + payment rows.
   */
  async debitDriverUnlockFee(
    manager: EntityManager,
    params: {
      driverId: string;
      tripId: string;
      feeAmount: number;
      currency: string;
    },
  ): Promise<void> {
    const { driverId, tripId, feeAmount, currency } = params;
    if (!Number.isFinite(feeAmount) || feeAmount <= 0) {
      throw new BadRequestException('Invalid unlock fee amount');
    }

    const idempotencyKey = `driver-unlock:${tripId}`;
    const existing = await manager.findOne(WalletTransactionEntity, {
      where: { idempotencyKey },
    });
    if (existing) {
      return;
    }

    const account = await this.getOrCreateAccountWithManager(
      manager,
      driverId,
      WalletAccountType.DRIVER,
      currency,
    );

    const locked = await manager.findOne(WalletAccountEntity, {
      where: { id: account.id },
      lock: { mode: 'pessimistic_write' },
    });
    if (!locked) {
      throw new NotFoundException('Wallet account not found');
    }

    const current = Number(locked.balance);
    if (current < feeAmount) {
      throw new BadRequestException(
        'Insufficient wallet balance. Please top up your wallet to confirm bookings and view passenger details.',
      );
    }

    locked.balance = (current - feeAmount).toFixed(2);
    await manager.save(locked);

    const tx = manager.create(WalletTransactionEntity, {
      accountId: locked.id,
      type: WalletTransactionType.TRIP_DEBIT,
      direction: WalletEntryDirection.DEBIT,
      status: WalletTransactionStatus.POSTED,
      amount: feeAmount.toFixed(2),
      currency: locked.currency,
      referenceType: 'trip',
      referenceId: tripId,
      idempotencyKey,
    });
    await manager.save(tx);
  }

  /**
   * Wallet balances are per (user, role bucket, currency). Default currency is JOD (Jordan).
   * Sums all accounts for this role bucket so the displayed balance matches ledger activity
   * (avoids picking one row when legacy duplicates or currency casing split balances).
   */
  async getWalletSummary(userId: string, role: string) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;

    const accounts = await this.walletAccountRepo.find({
      where: { userId, accountType },
      order: { updatedAt: 'DESC' },
    });

    if (accounts.length === 0) {
      const account = await this.getOrCreateAccount(userId, accountType);
      return {
        accountId: account.id,
        accountType: account.accountType,
        currency: account.currency,
        balance: Number(account.balance),
        isActive: account.isActive,
      };
    }

    const byCurrency = new Map<string, number>();
    for (const a of accounts) {
      const key = this.normalizeWalletCurrency(a.currency);
      byCurrency.set(key, (byCurrency.get(key) ?? 0) + Number(a.balance));
    }

    const primaryCurrency = byCurrency.has('JOD')
      ? 'JOD'
      : [...byCurrency.keys()][0];
    const totalBalance = byCurrency.get(primaryCurrency) ?? 0;

    const inPrimary = accounts.filter(
      (a) => this.normalizeWalletCurrency(a.currency) === primaryCurrency,
    );
    const representative =
      inPrimary.sort(
        (a, b) => Number(b.balance) - Number(a.balance),
      )[0] ?? accounts[0];

    return {
      accountId: representative.id,
      accountType: representative.accountType,
      currency: primaryCurrency,
      balance: totalBalance,
      isActive: accounts.every((a) => a.isActive),
    };
  }

  /**
   * Post a credit after a verified payment (e.g. admin-approved wallet top-up).
   * Idempotent per `idempotencyKey`.
   */
  async creditPostedTopup(params: {
    userId: string;
    accountType: WalletAccountType;
    amount: number;
    currency?: string;
    idempotencyKey: string;
    note?: string | null;
  }): Promise<WalletTransactionEntity> {
    const { userId, accountType, amount, idempotencyKey } = params;
    const currency = this.normalizeWalletCurrency(params.currency);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Invalid top-up amount');
    }

    const dup = await this.walletTxRepo.findOne({
      where: { idempotencyKey },
    });
    if (dup) {
      return dup;
    }

    const account = await this.getOrCreateAccount(userId, accountType, currency);

    return this.dataSource.transaction(async (manager) => {
      const locked = await manager.findOne(WalletAccountEntity, {
        where: { id: account.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) {
        throw new NotFoundException('Wallet account not found');
      }

      const current = Number(locked.balance);
      locked.balance = (current + amount).toFixed(2);
      await manager.save(locked);

      const tx = manager.create(WalletTransactionEntity, {
        accountId: locked.id,
        type: WalletTransactionType.TOPUP,
        direction: WalletEntryDirection.CREDIT,
        status: WalletTransactionStatus.POSTED,
        amount: amount.toFixed(2),
        currency: locked.currency,
        idempotencyKey,
        metadata: {
          note: params.note ?? null,
        },
      });
      return manager.save(tx);
    });
  }

  /** Direct HTTP instant top-up: admins only (testing / manual ops). */
  async createTopup(userId: string, role: string, dto: CreateTopupDto) {
    if (role !== 'admin') {
      throw new ForbiddenException(
        'Use POST /payments/wallet/topup with payment proof. Wallet credit is applied after admin approval.',
      );
    }
    // Admins use the rider ledger bucket for ad-hoc testing unless extended later.
    return this.creditPostedTopup({
      userId,
      accountType: WalletAccountType.RIDER,
      amount: dto.amount,
      currency: dto.currency,
      idempotencyKey: dto.idempotencyKey ?? randomUUID(),
      note: dto.note ?? null,
    });
  }

  async chargeDriverForTrip(driverId: string, dto: DriverTripChargeDto) {
    const trip = await this.tripRepo.findOne({
      where: { id: dto.tripId, driverId },
      select: ['id', 'driverId'],
    });
    if (!trip) {
      throw new NotFoundException('Trip not found for this driver');
    }

    const account = await this.getOrCreateAccount(
      driverId,
      WalletAccountType.DRIVER,
      'JOD',
    );
    const fee = 10;

    const existing = dto.idempotencyKey
      ? await this.walletTxRepo.findOne({
          where: { idempotencyKey: dto.idempotencyKey },
        })
      : null;
    if (existing) {
      return existing;
    }

    return this.dataSource.transaction(async (manager) => {
      const locked = await manager.findOne(WalletAccountEntity, {
        where: { id: account.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) {
        throw new NotFoundException('Wallet account not found');
      }

      const current = Number(locked.balance);
      if (current < fee) {
        throw new BadRequestException(
          'Insufficient wallet balance to activate trip',
        );
      }
      locked.balance = (current - fee).toFixed(2);
      await manager.save(locked);

      const tx = manager.create(WalletTransactionEntity, {
        accountId: locked.id,
        type: WalletTransactionType.TRIP_DEBIT,
        direction: WalletEntryDirection.DEBIT,
        status: WalletTransactionStatus.POSTED,
        amount: fee.toFixed(2),
        currency: locked.currency,
        referenceType: 'trip',
        referenceId: dto.tripId,
        idempotencyKey: dto.idempotencyKey ?? null,
      });
      return manager.save(tx);
    });
  }

  async payTripFromRiderWallet(
    riderId: string,
    tripId: string,
    amount: number,
    idempotencyKey?: string,
  ) {
    const riderAccount = await this.getOrCreateAccount(
      riderId,
      WalletAccountType.RIDER,
    );

    const existing = idempotencyKey
      ? await this.walletTxRepo.findOne({
          where: { idempotencyKey },
        })
      : null;
    if (existing) {
      return existing;
    }

    return this.dataSource.transaction(async (manager) => {
      const riderLocked = await manager.findOne(WalletAccountEntity, {
        where: { id: riderAccount.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!riderLocked) {
        throw new NotFoundException('Rider wallet not found');
      }
      if (Number(riderLocked.balance) < amount) {
        throw new BadRequestException('Insufficient rider wallet balance');
      }
      riderLocked.balance = (Number(riderLocked.balance) - amount).toFixed(2);
      await manager.save(riderLocked);

      const debitTx = manager.create(WalletTransactionEntity, {
        accountId: riderLocked.id,
        type: WalletTransactionType.TRIP_PAYMENT,
        direction: WalletEntryDirection.DEBIT,
        status: WalletTransactionStatus.POSTED,
        amount: amount.toFixed(2),
        currency: riderLocked.currency,
        referenceType: 'trip',
        referenceId: tripId,
        idempotencyKey: idempotencyKey ?? null,
      });

      return manager.save(debitTx);
    });
  }

  async createPayoutRequest(driverId: string, dto: CreatePayoutRequestDto) {
    const account = await this.getOrCreateAccount(
      driverId,
      WalletAccountType.DRIVER,
      dto.currency || 'JOD',
    );
    if (Number(account.balance) < dto.amount) {
      throw new BadRequestException('Insufficient wallet balance for payout');
    }

    return this.payoutRepo.save(
      this.payoutRepo.create({
        driverId,
        amount: dto.amount.toFixed(2),
        currency: dto.currency || account.currency,
        status: PayoutStatus.PENDING,
        bankAccountRef: dto.bankAccountRef ?? null,
        note: dto.note ?? null,
      } as Partial<PayoutRequestEntity>),
    );
  }

  /**
   * Debit rider for platform fee; wallet row stays PENDING until capture (driver confirms)
   * or release (cancel / trip departed without confirm).
   */
  async holdRiderPlatformFeeWithManager(
    manager: EntityManager,
    params: {
      riderId: string;
      bookingId: string;
      tripId: string;
      amount: number;
      currency: string;
      idempotencyKey: string;
    },
  ): Promise<WalletTransactionEntity> {
    const { riderId, bookingId, tripId, amount, currency, idempotencyKey } =
      params;
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Invalid hold amount');
    }

    const existing = await manager.findOne(WalletTransactionEntity, {
      where: { idempotencyKey },
    });
    if (existing) {
      return existing;
    }

    const account = await this.getOrCreateAccountWithManager(
      manager,
      riderId,
      WalletAccountType.RIDER,
      currency,
    );
    const locked = await manager.findOne(WalletAccountEntity, {
      where: { id: account.id },
      lock: { mode: 'pessimistic_write' },
    });
    if (!locked) {
      throw new NotFoundException('Rider wallet not found');
    }
    if (Number(locked.balance) < amount) {
      throw new BadRequestException('Insufficient rider wallet balance');
    }
    locked.balance = (Number(locked.balance) - amount).toFixed(2);
    await manager.save(locked);

    const tx = manager.create(WalletTransactionEntity, {
      accountId: locked.id,
      type: WalletTransactionType.HOLD,
      direction: WalletEntryDirection.DEBIT,
      status: WalletTransactionStatus.PENDING,
      amount: amount.toFixed(2),
      currency: locked.currency,
      referenceType: 'booking',
      referenceId: bookingId,
      idempotencyKey,
      metadata: { tripId },
    });
    return manager.save(tx);
  }

  async captureRiderHoldWithManager(
    manager: EntityManager,
    holdTxId: string,
  ): Promise<void> {
    const tx = await manager.findOne(WalletTransactionEntity, {
      where: { id: holdTxId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!tx) {
      throw new NotFoundException('Wallet hold not found');
    }
    if (tx.type !== WalletTransactionType.HOLD) {
      return;
    }
    if (tx.status !== WalletTransactionStatus.PENDING) {
      return;
    }
    tx.status = WalletTransactionStatus.POSTED;
    tx.type = WalletTransactionType.TRIP_PAYMENT;
    await manager.save(tx);
  }

  async releaseRiderHoldWithManager(
    manager: EntityManager,
    holdTxId: string,
  ): Promise<void> {
    const tx = await manager.findOne(WalletTransactionEntity, {
      where: { id: holdTxId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!tx) {
      return;
    }
    if (tx.type !== WalletTransactionType.HOLD) {
      return;
    }
    if (tx.status !== WalletTransactionStatus.PENDING) {
      return;
    }

    const account = await manager.findOne(WalletAccountEntity, {
      where: { id: tx.accountId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!account) {
      throw new NotFoundException('Wallet account not found');
    }
    const amount = Number(tx.amount);
    account.balance = (Number(account.balance) + amount).toFixed(2);
    await manager.save(account);

    tx.status = WalletTransactionStatus.REVERSED;
    await manager.save(tx);

    const refundDup = await manager.findOne(WalletTransactionEntity, {
      where: { idempotencyKey: `refund-hold:${tx.id}` },
    });
    if (refundDup) {
      return;
    }

    const refundTx = manager.create(WalletTransactionEntity, {
      accountId: account.id,
      type: WalletTransactionType.REFUND,
      direction: WalletEntryDirection.CREDIT,
      status: WalletTransactionStatus.POSTED,
      amount: tx.amount,
      currency: tx.currency,
      referenceType: 'booking',
      referenceId: tx.referenceId,
      idempotencyKey: `refund-hold:${tx.id}`,
      metadata: { originalHoldId: tx.id },
    });
    await manager.save(refundTx);
  }

  async getWalletTransactions(userId: string, role: string, limit = 50) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;
    const walletAccounts = await this.walletAccountRepo.find({
      where: { userId, accountType },
    });
    if (walletAccounts.length === 0) {
      await this.getOrCreateAccount(userId, accountType);
      return [];
    }
    const accountIds = walletAccounts.map((a) => a.id);
    const transactions = await this.walletTxRepo.find({
      where: { accountId: In(accountIds) },
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 200),
    });
    return transactions.map((tx) => ({
      id: tx.id,
      type: tx.type,
      direction: tx.direction,
      amount: Number(tx.amount),
      currency: tx.currency,
      referenceType: tx.referenceType,
      referenceId: tx.referenceId,
      createdAt: tx.createdAt,
    }));
  }
}
