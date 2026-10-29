import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { payoutNotice } from './payout-notices';
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
  PlatformSettingEntity,
  TripStatus,
  TripType,
} from '../../database/entities';
import { CreateTopupDto } from './dto/create-topup.dto';
import { CreatePayoutRequestDto } from './dto/create-payout-request.dto';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { ErrorCodes } from '../../common/errors/error-codes';
import { PlatformSettingsService } from '../platform-settings/platform-settings.service';
import { DriverWalletPolicyService } from './driver-wallet-policy.service';
import { NotificationsService } from '../notifications/notifications.service';
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
  private readonly logger = new Logger(WalletService.name);

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
    private readonly settings: PlatformSettingsService,
    private readonly policy: DriverWalletPolicyService,
    private readonly notifications: NotificationsService,
    @Optional() private readonly adminAlerts?: AdminAlertsService,
  ) {}

  async driverMinimum(currency: string): Promise<number> {
    return this.policy.minimum(currency);
  }

  commissionPercent(type: string) {
    return this.settings.getNumber(
      type === 'instant'
        ? 'instantCommissionPercent'
        : 'sharedCommissionPercent',
    );
  }

  /** The unique account insert and lock serialize all writers in a currency. */
  private async lockedAccount(
    manager: EntityManager,
    userId: string | null,
    accountType: WalletAccountType,
    currency: string,
  ): Promise<WalletAccountEntity> {
    await manager.query(
      `INSERT INTO wallet_accounts ("userId", "accountType", currency)
      VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`,
      [userId, accountType, currency],
    );
    const rows = await manager.query<{ id: string }[]>(
      `SELECT id FROM wallet_accounts
      WHERE "userId" IS NOT DISTINCT FROM $1::uuid AND "accountType"=$2 AND currency=$3`,
      [userId, accountType, currency],
    );
    return await manager.findOneOrFail(WalletAccountEntity, {
      where: { id: rows[0].id },
      lock: { mode: 'pessimistic_write' },
    });
  }

  private async post(
    manager: EntityManager,
    account: WalletAccountEntity,
    amount: number,
    key: string,
    type: WalletTransactionType,
    referenceId: string,
    metadata: Record<string, unknown> = {},
  ) {
    account.balance = (Number(account.balance) + amount).toFixed(2);
    await manager.save(WalletAccountEntity, account);
    return manager.save(
      WalletTransactionEntity,
      manager.create(WalletTransactionEntity, {
        accountId: account.id,
        currency: account.currency,
        amount: Math.abs(amount).toFixed(2),
        direction:
          amount < 0 ? WalletEntryDirection.DEBIT : WalletEntryDirection.CREDIT,
        status: WalletTransactionStatus.POSTED,
        type,
        idempotencyKey: key,
        referenceType: 'revenue',
        referenceId,
        metadata,
      }),
    );
  }

  /** Called inside the approval transaction; re-approval never grants again. */
  async grantDriverWelcome(
    driverId: string,
    currency: string,
    manager?: EntityManager,
  ) {
    const amount = await this.policy.minimum(currency);
    const grant = async (m: EntityManager) => {
      await m.findOneOrFail(UserEntity, {
        where: { id: driverId },
        lock: { mode: 'pessimistic_write' },
      });
      const key = `driver-welcome:${driverId}`;
      if (
        await m.findOne(WalletTransactionEntity, {
          where: { idempotencyKey: key },
        })
      )
        return;
      const account = await this.lockedAccount(
        m,
        driverId,
        WalletAccountType.DRIVER,
        currency,
      );
      await this.post(
        m,
        account,
        amount,
        key,
        WalletTransactionType.ADJUSTMENT,
        driverId,
        { reason: 'driver_welcome_credit', minimumAtGrant: amount },
      );
      await this.syncUserLegacyWalletMirror(
        driverId,
        WalletAccountType.DRIVER,
        m,
      );
    };
    return manager ? grant(manager) : this.dataSource.transaction(grant);
  }

  /** Actual completed bookings only. Driver debit + system credit + stamp commit together. */
  async chargeCompletedTripCommission(tripId: string) {
    const outcome = await this.dataSource.transaction(async (m) => {
      const trip = await m.findOneOrFail(TripEntity, {
        where: { id: tripId },
        lock: { mode: 'pessimistic_write' },
      });
      const empty = {
        tripId,
        charged: 0,
        pendingRemainder: 0,
        currency: trip.currency,
        applied: false,
      };
      if (trip.status !== TripStatus.COMPLETED) return empty;
      if (trip.driverWalletChargeApplied)
        return { ...empty, charged: Number(trip.capturedFeeAmount ?? 0) };
      const cutover = await m.findOne(PlatformSettingEntity, {
        where: { key: 'commission.cutover' },
      });
      if (!cutover)
        throw new BadRequestException('Revenue migration is required');
      if (
        trip.tripCompletedAt &&
        trip.tripCompletedAt < new Date(cutover.value)
      )
        return empty;
      // Preserve any debit that was posted by the old start-time fee worker.
      if (
        await m.findOne(WalletTransactionEntity, {
          where: { idempotencyKey: `trip-fee:${tripId}` },
        })
      )
        return empty;
      const bookings = await m.find(BookingEntity, {
        where: { tripId, status: BookingStatus.COMPLETED },
        relations: ['seats'],
      });
      const grossCents = bookings.reduce((sum, b) => {
        const fareCents = Math.round(
          Number(b.originalAmount ?? b.totalAmount) * 100,
        );
        if (trip.tripType === TripType.INSTANT) return sum + fareCents;
        // Driver confirmation alone never authorizes shared-trip commission.
        // Legacy bookings without seat rows use the passenger's booking confirmation.
        if (!b.seats?.length) {
          return sum + (b.passengerPresenceConfirmedAt ? fareCents : 0);
        }
        const confirmed = b.seats.filter(
          (seat) =>
            seat.passengerSelfConfirmedAt != null &&
            seat.billableOverride !== false,
        ).length;
        const seatCount = Number(b.seatCount);
        if (!Number.isInteger(seatCount) || seatCount < b.seats.length) {
          throw new BadRequestException('Invalid booking seat count');
        }
        return sum + Math.round((fareCents * confirmed) / seatCount);
      }, 0);
      const percent = await this.settings.getNumber(
        trip.tripType === TripType.INSTANT
          ? 'instantCommissionPercent'
          : 'sharedCommissionPercent',
      );
      if (
        !Number.isFinite(percent) ||
        percent < 0 ||
        percent > 100 ||
        grossCents < 0
      )
        throw new BadRequestException('Invalid commission basis');
      const fee = Math.round((grossCents * percent) / 100) / 100;
      const driver = await this.lockedAccount(
        m,
        trip.driverId,
        WalletAccountType.DRIVER,
        trip.currency,
      );
      const system = await this.lockedAccount(
        m,
        null,
        WalletAccountType.SYSTEM,
        trip.currency,
      );
      await this.post(
        m,
        driver,
        -fee,
        `commission:${tripId}`,
        WalletTransactionType.TRIP_DEBIT,
        tripId,
        { percent, grossAmount: grossCents / 100, tripType: trip.tripType },
      );
      await this.post(
        m,
        system,
        fee,
        `commission-income:${tripId}`,
        WalletTransactionType.TRIP_PAYMENT,
        tripId,
      );
      // The platform funds promotions, so driver earnings never shrink.
      // Cash: reimburse the discount. Electronic: reimburse + collect the net fare.
      const discount =
        bookings.reduce(
          (sum, b) => sum + Math.round(Number(b.discountAmount ?? 0) * 100),
          0,
        ) / 100;
      if (discount > 0) {
        await this.post(
          m,
          driver,
          discount,
          `promotion-driver:${tripId}`,
          WalletTransactionType.ADJUSTMENT,
          tripId,
          { reason: 'platform_funded_promotion' },
        );
        await this.post(
          m,
          system,
          -discount,
          `promotion-platform:${tripId}`,
          WalletTransactionType.ADJUSTMENT,
          tripId,
          { reason: 'passenger_promotion_expense' },
        );
      }
      const depleted =
        Number(driver.balance) - Number(driver.reservedBalance ?? 0) <= 0;
      if (depleted) {
        driver.rechargeRequired = true;
        await m.save(driver);
        await m.query(
          `UPDATE driver_availability SET "isOnline"=false WHERE "driverId"=$1`,
          [trip.driverId],
        );
      }
      trip.driverWalletChargeApplied = true;
      trip.driverWalletChargeAt = new Date();
      trip.capturedFeeAmount = fee.toFixed(2);
      trip.communicationFeeStatus = 'paid';
      await m.save(trip);
      await this.syncUserLegacyWalletMirror(
        trip.driverId,
        WalletAccountType.DRIVER,
        m,
      );
      return {
        ...empty,
        charged: fee,
        applied: true,
        depleted,
        driverId: trip.driverId,
      };
    });
    if ('depleted' in outcome && outcome.depleted && outcome.driverId) {
      const minimum = await this.policy
        .minimum(outcome.currency)
        .catch(() => null);
      await this.notifications
        .create({
          userId: outcome.driverId,
          type: 'wallet_recharge_required',
          title: 'اشحن محفظتك للاستمرار',
          body: `توقف استقبال الرحلات وإنشاؤها. اشحن محفظتك بحد أدنى ${minimum ?? 'ما يعادل 5 دنانير'} ${minimum ? outcome.currency : ''} مع تسديد أي رصيد سالب.`,
          data: { minimumTopup: minimum, currency: outcome.currency },
        })
        .catch(() => undefined);
    }
    return outcome;
  }

  async assertDriverTopup(userId: string, amount: number, currency: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (user?.role !== 'driver') return;
    const minimum = await this.policy.minimum(currency);
    if (!Number.isFinite(amount) || amount < minimum) {
      throw new BadRequestException(`الحد الأدنى للشحن ${minimum} ${currency}`);
    }
  }

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

    const minimum =
      accountType === WalletAccountType.DRIVER
        ? await this.policy.minimum(account.currency)
        : 0;
    return {
      accountId: account.id,
      accountType: account.accountType,
      currency: account.currency,
      balance,
      reservedBalance: reserved,
      availableBalance: Math.round((balance - reserved) * 100) / 100,
      isActive: account.isActive,
      minimumTopup: minimum,
      minimumRetainedBalance: minimum,
      withdrawableBalance: Math.max(
        0,
        Math.round((balance - reserved - minimum) * 100) / 100,
      ),
      rechargeRequired: account.rechargeRequired || balance - reserved <= 0,
      exchangeRateProvider:
        minimum && !['JOD', 'SAR'].includes(account.currency)
          ? 'https://www.exchangerate-api.com'
          : null,
    };
  }

  /**
   * Blocks drivers with a negative ledger balance from creating shared trips
   * or going online for instant rides until they top up / settle.
   */
  async assertNonNegativeDriverBalance(
    driverId: string,
    currency?: string,
  ): Promise<void> {
    // A debt in any currency blocks, not only in the one the wallet shows.
    const accounts = await this.walletAccountRepo.find({
      where: { userId: driverId, accountType: WalletAccountType.DRIVER },
    });
    const inDebt = accounts.find(
      (a) => Number(a.balance) < 0 || a.rechargeRequired,
    );
    if (
      inDebt ||
      !accounts.some(
        (a) =>
          (!currency || a.currency === currency) &&
          a.isActive &&
          Number(a.balance) - Number(a.reservedBalance ?? 0) > 0,
      )
    ) {
      throw new ForbiddenException({
        code: ErrorCodes.NEGATIVE_WALLET_BALANCE,
        message:
          'اشحن محفظتك بحد أدنى 5 دنانير أو 25 ريالاً أو ما يعادلها وسدد أي مستحقات للاستمرار في استقبال الرحلات وإنشائها.',
        balance: Number(inDebt?.balance ?? 0),
        currency: inDebt?.currency,
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

      const alreadyPosted = await manager.findOne(WalletTransactionEntity, {
        where: { idempotencyKey },
      });
      if (alreadyPosted) return alreadyPosted;

      const current = Number(locked.balance);
      locked.balance = (current + amount).toFixed(2);
      if (
        accountType === WalletAccountType.DRIVER &&
        (!params.type || params.type === WalletTransactionType.TOPUP) &&
        amount >= (await this.policy.minimum(currency)) &&
        Number(locked.balance) > 0
      ) {
        locked.rechargeRequired = false;
      }
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

  /** Fare comes from the booking; the client can never choose the amount or currency. */
  async payTripFromRiderWallet(
    riderId: string,
    tripId: string,
    _amount?: number,
    _key?: string,
  ) {
    // Retained for older clients; only the persisted booking determines the debit.
    void _amount;
    void _key;
    const booking = await this.dataSource.getRepository(BookingEntity).findOne({
      where: { tripId, userId: riderId, status: BookingStatus.COMPLETED },
      order: { createdAt: 'DESC' },
    });
    if (!booking) throw new NotFoundException('لا يوجد حجز مكتمل للدفع.');
    if (booking.paymentMethod !== 'wallet')
      throw new BadRequestException('الحجز لا يستخدم المحفظة.');
    return this.settleCollectedFare(booking.id, 'wallet', riderId);
  }

  /** CliQ is called only after provider verification; wallet debit is internal. */
  async settleCollectedFare(
    bookingId: string,
    method: 'wallet' | 'cliq' | 'cash',
    riderId?: string,
  ) {
    const initial = await this.dataSource
      .getRepository(BookingEntity)
      .findOneOrFail({ where: { id: bookingId } });
    await this.chargeCompletedTripCommission(initial.tripId);
    return this.dataSource.transaction(async (m) => {
      const b = await m.findOneOrFail(BookingEntity, {
        where: { id: bookingId },
        lock: { mode: 'pessimistic_write' },
      });
      if (riderId && b.userId !== riderId) throw new ForbiddenException();
      if (b.paymentStatus === 'paid') return b;
      if (
        b.status !== BookingStatus.COMPLETED ||
        b.paymentMethod !== method ||
        b.paymentStatus === 'disputed'
      ) {
        throw new BadRequestException('لا يمكن تسوية هذا الحجز الآن.');
      }
      const trip = await m.findOneOrFail(TripEntity, {
        where: { id: b.tripId },
      });
      const amount = Number(b.totalAmount);
      if (
        !Number.isFinite(amount) ||
        amount < 0 ||
        (method === 'cash' && amount !== 0)
      )
        throw new BadRequestException('Invalid fare');
      if (method === 'wallet' && amount > 0) {
        const rider = await this.lockedAccount(
          m,
          b.userId,
          WalletAccountType.RIDER,
          trip.currency,
        );
        if (
          !rider.isActive ||
          Number(rider.balance) - Number(rider.reservedBalance) < amount
        ) {
          throw new BadRequestException('رصيد محفظة الراكب غير كافٍ.');
        }
        await this.post(
          m,
          rider,
          -amount,
          `rider-fare:${b.id}`,
          WalletTransactionType.TRIP_PAYMENT,
          b.id,
        );
        await this.syncUserLegacyWalletMirror(
          b.userId,
          WalletAccountType.RIDER,
          m,
        );
      }
      const driver = await this.lockedAccount(
        m,
        trip.driverId,
        WalletAccountType.DRIVER,
        trip.currency,
      );
      // Commission already debited at completion: credit gross, leaving exactly net earnings.
      if (
        !(await m.findOne(WalletTransactionEntity, {
          where: { idempotencyKey: `ride-fare:${b.id}` },
        }))
      ) {
        await this.post(
          m,
          driver,
          amount,
          `ride-fare:${b.id}`,
          WalletTransactionType.TRIP_PAYMENT,
          b.id,
          { method, commissionChargedAtCompletion: true },
        );
      }
      if (
        Number(driver.balance) - Number(driver.reservedBalance) >=
        (await this.policy.minimum(trip.currency))
      ) {
        driver.rechargeRequired = false;
        await m.save(driver);
      }
      b.paymentStatus = 'paid';
      b.settledAt = new Date();
      await m.save(b);
      await this.syncUserLegacyWalletMirror(
        trip.driverId,
        WalletAccountType.DRIVER,
        m,
      );
      return b;
    });
  }

  async createPayoutRequest(driverId: string, dto: CreatePayoutRequestDto) {
    const currency =
      dto.currency || (await this.resolveLocalCurrency(driverId)) || 'JOD';
    const minimum = await this.policy.minimum(currency);
    if (
      !Number.isFinite(dto.amount) ||
      dto.amount <= 0 ||
      Math.abs(Math.round(dto.amount * 100) - dto.amount * 100) > 1e-7
    ) {
      throw new BadRequestException('Invalid payout amount');
    }
    if (!dto.bankAccountRef?.trim())
      throw new BadRequestException('أدخل حساب CliQ لاستلام الأرباح.');
    const bankAccountRef = dto.bankAccountRef.trim();
    const payout = await this.dataSource.transaction(async (m) => {
      const a = await this.lockedAccount(
        m,
        driverId,
        WalletAccountType.DRIVER,
        currency,
      );
      if (
        !a.isActive ||
        Number(a.balance) - Number(a.reservedBalance) - dto.amount < minimum
      ) {
        throw new BadRequestException(
          `يجب الإبقاء على ${minimum} ${currency} في المحفظة بعد السحب.`,
        );
      }
      a.reservedBalance = (Number(a.reservedBalance) + dto.amount).toFixed(2);
      await m.save(a);
      return m.save(
        PayoutRequestEntity,
        m.create(PayoutRequestEntity, {
          driverId,
          amount: dto.amount.toFixed(2),
          currency,
          status: PayoutStatus.PENDING,
          bankAccountRef,
          note: dto.note ?? null,
        }),
      );
    });
    void this.userRepo
      .findOne({ where: { id: driverId }, select: ['id', 'name'] })
      .then((driver) =>
        this.adminAlerts?.notifyPayoutRequest({
          id: payout.id,
          amount: payout.amount,
          currency: payout.currency,
          driverName: driver?.name,
        }),
      )
      .catch((err: Error) =>
        this.logger.warn(`Payout alert failed: ${err.message}`),
      );
    return payout;
  }

  listPayouts(driverId?: string) {
    return this.payoutRepo.find({
      where: driverId ? { driverId } : {},
      order: { createdAt: 'DESC' },
      take: 200,
    });
  }

  /** Admin marks paid only after making the external manual transfer. */
  async processPayout(
    id: string,
    adminId: string,
    status: PayoutStatus,
    note?: string,
  ) {
    const processed = await this.dataSource.transaction(async (m) => {
      const p = await m.findOneOrFail(PayoutRequestEntity, {
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (p.status === status) return p;
      if ([PayoutStatus.PAID, PayoutStatus.REJECTED].includes(p.status))
        throw new BadRequestException('الطلب مغلق.');
      if (
        ![
          PayoutStatus.APPROVED,
          PayoutStatus.PAID,
          PayoutStatus.REJECTED,
        ].includes(status)
      )
        throw new BadRequestException('Invalid status');
      const a = await this.lockedAccount(
        m,
        p.driverId,
        WalletAccountType.DRIVER,
        p.currency,
      );
      const amount = Number(p.amount);
      if (status === PayoutStatus.PAID) {
        const minimum = await this.policy.minimum(p.currency);
        if (Number(a.balance) - Number(a.reservedBalance) < minimum)
          throw new BadRequestException('الرصيد المتبقي لا يغطي الحد الأدنى.');
        await this.post(
          m,
          a,
          -amount,
          `payout:${p.id}`,
          WalletTransactionType.PAYOUT,
          p.id,
          { adminId },
        );
      }
      if (status === PayoutStatus.PAID || status === PayoutStatus.REJECTED) {
        a.reservedBalance = Math.max(
          0,
          Number(a.reservedBalance) - amount,
        ).toFixed(2);
        await m.save(a);
      }
      p.status = status;
      p.processedByAdminId = adminId;
      p.processedAt = new Date();
      if (note) p.note = note;
      await m.save(p);
      await this.syncUserLegacyWalletMirror(
        p.driverId,
        WalletAccountType.DRIVER,
        m,
      );
      return p;
    });
    const notice = payoutNotice(processed);
    if (notice) {
      this.notifications
        .create(notice)
        .catch((err: Error) =>
          this.logger.warn(`Payout notice failed: ${err.message}`),
        );
    }
    return processed;
  }

  platformBalances() {
    return this.walletAccountRepo.find({
      where: { accountType: WalletAccountType.SYSTEM },
      order: { currency: 'ASC' },
    });
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
