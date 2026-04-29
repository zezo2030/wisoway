import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
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

  private async getOrCreateAccount(
    userId: string,
    accountType: WalletAccountType,
    currency = 'JOD',
  ) {
    let account = await this.walletAccountRepo.findOne({
      where: { userId, accountType, currency },
    });
    if (!account) {
      account = this.walletAccountRepo.create({
        userId,
        accountType,
        currency,
        balance: '0',
        isActive: true,
      });
      account = await this.walletAccountRepo.save(account);
    }
    return account;
  }

  /**
   * Wallet balances are per (user, role bucket, currency). Default currency is JOD (Jordan).
   * When multiple accounts exist, we pick the best row to display (see below).
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

    const positive = accounts.filter((a) => Number(a.balance) > 0);
    const account =
      positive.sort((a, b) => Number(b.balance) - Number(a.balance))[0] ??
      accounts.find((a) => a.currency === 'JOD') ??
      accounts[0];

    return {
      accountId: account.id,
      accountType: account.accountType,
      currency: account.currency,
      balance: Number(account.balance),
      isActive: account.isActive,
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
    const currency = params.currency || 'JOD';
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Invalid top-up amount');
    }

    const dup = await this.walletTxRepo.findOne({
      where: { idempotencyKey },
    });
    if (dup) {
      return dup;
    }

    const account = await this.getOrCreateAccount(
      userId,
      accountType,
      currency,
    );

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

  async adjustBalanceByAdmin(params: {
    accountId: string;
    amount: number;
    note?: string | null;
    currency?: string;
    adminId: string;
  }): Promise<WalletTransactionEntity> {
    const { accountId, amount, adminId } = params;
    if (!Number.isFinite(amount) || amount === 0) {
      throw new BadRequestException('Adjustment amount must be non-zero');
    }

    const account = await this.walletAccountRepo.findOne({
      where: { id: accountId },
    });
    if (!account) {
      throw new NotFoundException('Wallet account not found');
    }

    if (params.currency && params.currency !== account.currency) {
      throw new BadRequestException('Currency does not match wallet currency');
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
      const nextBalance = current + amount;
      if (nextBalance < 0) {
        throw new BadRequestException(
          'Adjustment would make wallet balance negative',
        );
      }

      locked.balance = nextBalance.toFixed(2);
      await manager.save(locked);

      const tx = manager.create(WalletTransactionEntity, {
        accountId: locked.id,
        type: WalletTransactionType.ADJUSTMENT,
        direction:
          amount > 0 ? WalletEntryDirection.CREDIT : WalletEntryDirection.DEBIT,
        status: WalletTransactionStatus.POSTED,
        amount: Math.abs(amount).toFixed(2),
        currency: locked.currency,
        metadata: {
          note: params.note ?? null,
          adminId,
          balanceBefore: current.toFixed(2),
          balanceAfter: nextBalance.toFixed(2),
        },
      });
      return manager.save(tx);
    });
  }

  async chargeDriverForTrip(driverId: string, dto: DriverTripChargeDto) {
    const trip = await this.tripRepo.findOne({
      where: { id: dto.tripId, driverId },
    });
    if (!trip) {
      throw new NotFoundException('Trip not found for this driver');
    }
    if (trip.driverWalletChargeApplied) {
      const existingTripCharge = await this.walletTxRepo.findOne({
        where: {
          referenceType: 'trip',
          referenceId: dto.tripId,
          type: WalletTransactionType.TRIP_DEBIT,
        },
        order: { createdAt: 'DESC' },
      });
      if (existingTripCharge) return existingTripCharge;
      throw new BadRequestException('Trip fee has already been paid');
    }

    const account = await this.getOrCreateAccount(
      driverId,
      WalletAccountType.DRIVER,
      trip.currency || 'JOD',
    );
    const seatPrice = Number(trip.price ?? 0);
    const totalSeats = Number(trip.totalSeats ?? 0);
    const fee = Math.round(seatPrice * totalSeats * 0.05 * 100) / 100;

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
        metadata: {
          seatPrice,
          totalSeats,
          percent: 5,
          formula: 'seatPrice * totalSeats * 5%',
        },
      });
      const savedTx = await manager.save(tx);

      await manager.update(
        TripEntity,
        { id: dto.tripId },
        {
          driverWalletChargeApplied: true,
          driverWalletChargeAt: new Date(),
          communicationFeeStatus: 'paid',
        },
      );
      await manager.update(
        BookingEntity,
        {
          tripId: dto.tripId,
          status: In([BookingStatus.PENDING, BookingStatus.CONFIRMED]),
        },
        { hasDriverPaidToContact: true },
      );

      return savedTx;
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
