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
  BookingEntity,
  BookingStatus,
  PayoutRequestEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletEntryDirection,
  WalletHoldEntity,
  WalletHoldStatus,
  PayoutStatus,
  WalletTransactionEntity,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { CreateTopupDto } from './dto/create-topup.dto';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { ErrorCodes } from '../../common/errors/error-codes';
import {
  countryForPhone,
  knownCurrencyForCountry,
} from '../../common/currency/country-currency';

/** True when the account holds, owes or reserves anything. */
function carriesFunds(account: WalletAccountEntity): boolean {
  return (
    Number(account.balance) !== 0 || Number(account.reservedBalance ?? 0) !== 0
  );
}

/**
 * Primary ledger row for a (user, bucket). Money is never relabelled, so a row
 * that carries funds always beats an empty one: the preferred currency's row
 * if it carries funds, else the highest positive balance, else any row in
 * debt; only among empty rows do the preferred currency, then JOD, win.
 */
export function pickPrimaryWalletLedgerAccount(
  accounts: WalletAccountEntity[],
  preferredCurrency?: string | null,
): WalletAccountEntity | null {
  if (accounts.length === 0) return null;
  const preferred = preferredCurrency
    ? accounts.find((a) => a.currency === preferredCurrency)
    : undefined;
  if (preferred && carriesFunds(preferred)) return preferred;
  const positive = accounts.filter((a) => Number(a.balance) > 0);
  return (
    [...positive].sort((a, b) => Number(b.balance) - Number(a.balance))[0] ??
    accounts.find(carriesFunds) ??
    preferred ??
    accounts.find((a) => a.currency === 'JOD') ??
    accounts[0]
  );
}

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
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly platformPricing: PlatformPricingService,
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
   * Keeps legacy `users.walletBalance` / `walletCurrency` aligned with the ledger row
   * the app treats as “primary” for that bucket (matches GET /wallet/me summary).
   */
  async syncUserLegacyWalletMirror(
    userId: string,
    accountType: WalletAccountType,
    manager: EntityManager,
  ): Promise<void> {
    const accounts = await manager.find(WalletAccountEntity, {
      where: { userId, accountType },
    });
    const primary = pickPrimaryWalletLedgerAccount(accounts);
    if (!primary) return;
    await manager.update(
      UserEntity,
      { id: userId },
      {
        walletBalance: Number(primary.balance),
        walletCurrency: primary.currency,
      },
    );
  }

  /**
   * Currency of the country the user is in: the country the app reports from
   * the device location, else the one their phone number belongs to. Null when
   * neither is known, which keeps the legacy JOD default.
   */
  async resolveLocalCurrency(
    userId: string,
    countryCode?: string | null,
  ): Promise<string | null> {
    const fromLocation = knownCurrencyForCountry(countryCode);
    if (fromLocation) return fromLocation;
    const user = await this.userRepo.findOne({
      where: { id: userId },
      select: { id: true, phoneNumber: true },
    });
    return knownCurrencyForCountry(countryForPhone(user?.phoneNumber));
  }

  /**
   * Wallet balances are per (user, role bucket, currency). With a
   * [preferredCurrency] (the user's local one) an empty wallet is shown in that
   * currency; a balance held in another currency is still shown as it is.
   * Without one the default currency is JOD (Jordan).
   */
  async getWalletSummary(
    userId: string,
    role: string,
    preferredCurrency?: string | null,
  ) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;

    const accounts = await this.walletAccountRepo.find({
      where: { userId, accountType },
      order: { updatedAt: 'DESC' },
    });

    let account = pickPrimaryWalletLedgerAccount(accounts, preferredCurrency);
    if (
      preferredCurrency &&
      (!account ||
        (account.currency !== preferredCurrency && !carriesFunds(account)))
    ) {
      account = await this.getOrCreateAccount(
        userId,
        accountType,
        preferredCurrency,
      );
    }
    account ??= await this.getOrCreateAccount(userId, accountType);

    // `balance` is what the account owns; `reserved` is the part promised to
    // active trip holds. Drivers spend against `available`.
    const balance = Number(account.balance);
    const reserved = Number(account.reservedBalance ?? 0);

    return {
      accountId: account.id,
      accountType: account.accountType,
      currency: account.currency,
      balance,
      reservedBalance: reserved,
      availableBalance: Math.round((balance - reserved) * 100) / 100,
      isActive: account.isActive,
    };
  }

  /**
   * Blocks drivers with a negative ledger balance from creating shared trips
   * or going online for instant rides until they top up / settle.
   */
  async assertNonNegativeDriverBalance(driverId: string): Promise<void> {
    // A debt in any currency blocks, not only in the one the wallet shows.
    const accounts = await this.walletAccountRepo.find({
      where: { userId: driverId, accountType: WalletAccountType.DRIVER },
    });
    const inDebt = accounts.find((a) => Number(a.balance) < 0);
    if (inDebt) {
      throw new ForbiddenException({
        code: ErrorCodes.NEGATIVE_WALLET_BALANCE,
        message:
          'رصيد محفظتك سالب. سدد المستحقات قبل إنشاء رحلات مشتركة أو تلقي رحلات مباشرة.',
        balance: Number(inDebt.balance),
        currency: inDebt.currency,
      });
    }
  }

  /** Balance of the user's ledger row in exactly [currency]; 0 when there is none. */
  async getBalanceIn(
    userId: string,
    accountType: WalletAccountType,
    currency: string,
  ): Promise<number> {
    const account = await this.walletAccountRepo.findOne({
      where: { userId, accountType, currency },
    });
    return Number(account?.balance ?? 0);
  }

  /** Active holds for a user — surfaced in the driver wallet screen. */
  async getActiveHolds(userId: string, role: string) {
    const accountType =
      role === WalletAccountType.DRIVER
        ? WalletAccountType.DRIVER
        : WalletAccountType.RIDER;

    const accounts = await this.walletAccountRepo.find({
      where: { userId, accountType },
    });
    if (accounts.length === 0) return [];

    const holds = await this.dataSource.getRepository(WalletHoldEntity).find({
      where: {
        accountId: In(accounts.map((a) => a.id)),
        status: WalletHoldStatus.ACTIVE,
      },
      order: { createdAt: 'DESC' },
    });

    return holds.map((h) => ({
      id: h.id,
      amount: Number(h.amount),
      currency: h.currency,
      referenceType: h.referenceType,
      referenceId: h.referenceId,
      createdAt: h.createdAt,
    }));
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
    /** Defaults to a top-up; ride fares the platform collected post as TRIP_PAYMENT. */
    type?: WalletTransactionType;
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
        type: params.type ?? WalletTransactionType.TOPUP,
        direction: WalletEntryDirection.CREDIT,
        status: WalletTransactionStatus.POSTED,
        amount: amount.toFixed(2),
        currency: locked.currency,
        idempotencyKey,
        metadata: {
          note: params.note ?? null,
        },
      });
      const savedTx = await manager.save(tx);
      await this.syncUserLegacyWalletMirror(userId, accountType, manager);
      return savedTx;
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
