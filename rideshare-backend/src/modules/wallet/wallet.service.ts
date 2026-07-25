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
import { DriverTripChargeDto } from './dto/driver-trip-charge.dto';
import { WalletHoldService } from './wallet-hold.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';

/** Primary ledger row for a (user, bucket): highest positive balance, else JOD, else first. */
export function pickPrimaryWalletLedgerAccount(
  accounts: WalletAccountEntity[],
): WalletAccountEntity | null {
  if (accounts.length === 0) return null;
  const positive = accounts.filter((a) => Number(a.balance) > 0);
  return (
    [...positive].sort((a, b) => Number(b.balance) - Number(a.balance))[0] ??
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
    private readonly walletHolds: WalletHoldService,
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

    const account =
      accounts.length === 0
        ? await this.getOrCreateAccount(userId, accountType)
        : pickPrimaryWalletLedgerAccount(accounts)!;

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

  /**
   * Driver unlocks passenger contact for a trip.
   *
   * Since 012-passenger-presence-confirmation this RESERVES the worst-case fee
   * instead of debiting it. `balance` does not move here — it moves at trip
   * settlement, and only for seats confirmed present. The hold is sized on
   * `totalSeats` so the capture (which is bounded by booked seats) can never
   * exceed what was reserved.
   *
   * Set PRESENCE_BILLING_ENABLED=false to fall back to the legacy immediate
   * debit while the mobile screens roll out.
   */
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
          type: In([
            WalletTransactionType.TRIP_DEBIT,
            WalletTransactionType.HOLD,
          ]),
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

    // Single source of truth for the percentage (was hardcoded 0.1 here while
    // PlatformPricingService read communication_fees.driverUnlockPercent).
    // 'JO' matches the existing convention in BookingsService/TripsService —
    // TripEntity carries no country column yet.
    const feeRow = await this.platformPricing.getActiveFeeRow('JO');
    const pricing = this.platformPricing.driverUnlockPricing(trip, feeRow);
    const seatPrice = pricing.seatPrice;
    const totalSeats = pricing.totalSeats;
    const percent = pricing.driverUnlockPercent;
    const maxFee = pricing.feeAmount;

    const existing = dto.idempotencyKey
      ? await this.walletTxRepo.findOne({
          where: { idempotencyKey: dto.idempotencyKey },
        })
      : null;
    if (existing) {
      return existing;
    }

    const pricingSnapshot = {
      seatPrice,
      totalSeats,
      percent,
      formula: 'seatPrice * billableSeats * percent%',
      basis: 'presence-confirmed seats',
    };

    return this.dataSource.transaction(async (manager) => {
      const driver = await manager.findOne(UserEntity, {
        where: { id: driverId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!driver) {
        throw new NotFoundException('User not found');
      }

      const locked = await manager.findOne(WalletAccountEntity, {
        where: { id: account.id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) {
        throw new NotFoundException('Wallet account not found');
      }

      const markTripUnlocked = async (holdId: string | null) => {
        await manager.update(
          TripEntity,
          { id: dto.tripId },
          {
            driverWalletChargeApplied: true,
            driverWalletChargeAt: new Date(),
            communicationFeeStatus: 'paid',
            ...(holdId ? { driverFeeHoldId: holdId } : {}),
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
      };

      // Lifetime free trip: no hold, no capture — settlement finds no hold and
      // no-ops, so the driver is never charged for this trip.
      if (!driver.hasUsedLifetimeFreeTrip) {
        driver.hasUsedLifetimeFreeTrip = true;
        await manager.save(driver);

        const freeTripTx = await manager.save(
          manager.create(WalletTransactionEntity, {
            accountId: locked.id,
            type: WalletTransactionType.TRIP_DEBIT,
            direction: WalletEntryDirection.DEBIT,
            status: WalletTransactionStatus.POSTED,
            amount: '0.00',
            currency: locked.currency,
            referenceType: 'trip',
            referenceId: dto.tripId,
            idempotencyKey: dto.idempotencyKey ?? null,
            metadata: {
              ...pricingSnapshot,
              freeTripApplied: true,
              discountPercent: 100,
            },
          }),
        );

        await markTripUnlocked(null);
        return freeTripTx;
      }

      if (!this.presenceBillingEnabled()) {
        // Legacy path — immediate debit of the worst-case fee.
        const current = Number(locked.balance);
        if (current < maxFee) {
          throw new BadRequestException(
            'Insufficient wallet balance to activate trip',
          );
        }
        locked.balance = (current - maxFee).toFixed(2);
        await manager.save(locked);

        const tx = await manager.save(
          manager.create(WalletTransactionEntity, {
            accountId: locked.id,
            type: WalletTransactionType.TRIP_DEBIT,
            direction: WalletEntryDirection.DEBIT,
            status: WalletTransactionStatus.POSTED,
            amount: maxFee.toFixed(2),
            currency: locked.currency,
            referenceType: 'trip',
            referenceId: dto.tripId,
            idempotencyKey: dto.idempotencyKey ?? null,
            metadata: {
              seatPrice,
              totalSeats,
              percent,
              formula: 'seatPrice * totalSeats * percent%',
            },
          }),
        );

        await markTripUnlocked(null);
        return tx;
      }

      const hold = await this.walletHolds.placeHold({
        accountId: locked.id,
        amount: maxFee,
        referenceType: 'trip',
        referenceId: dto.tripId,
        metadata: pricingSnapshot,
        manager,
      });

      await markTripUnlocked(hold.id);
      return hold;
    });
  }

  /** Feature flag — presence-based settlement. Defaults ON. */
  private presenceBillingEnabled(): boolean {
    return process.env.PRESENCE_BILLING_ENABLED !== 'false';
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
