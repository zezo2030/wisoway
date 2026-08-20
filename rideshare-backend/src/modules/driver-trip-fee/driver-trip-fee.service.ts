/**
 * DriverTripFeeService
 *
 * Owns the shared-trip platform fee end to end: the quote shown before
 * publishing, the balance guard at publish, and the single debit at trip start.
 *
 * The fee is deliberately based on the trip's TOTAL seat count, not on booked
 * or presence-confirmed seats — a driver pays the same whether the car fills or
 * not. It is charged once, when the trip starts, and is never refunded or
 * recomputed afterwards.
 */
import { ForbiddenException, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, In, Repository } from 'typeorm';
import {
  BookingEntity,
  PendingChargeEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletEntryDirection,
  WalletTransactionEntity,
  WalletTransactionStatus,
  WalletTransactionType,
} from '../../database/entities';
import { BookingStatus } from '../../database/entities/booking.entity';
import { PendingChargeKind } from '../../database/entities/pending-charge.entity';
import { ErrorCodes } from '../../common/errors/error-codes';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import {
  pickPrimaryWalletLedgerAccount,
  WalletService,
} from '../wallet/wallet.service';

export interface TripFeeBasis {
  seatPrice: number;
  totalSeats: number;
  currency?: string | null;
}

export interface TripFeeQuote {
  amount: number;
  seatPrice: number;
  totalSeats: number;
  percent: number;
  currency: string;
}

export interface TripFeeChargeResult {
  tripId: string;
  /** Actually debited from the wallet. */
  charged: number;
  /** Recorded as a PendingCharge; 0 when the fee was paid in full. */
  pendingRemainder: number;
  currency: string;
  /** False when the call short-circuited on idempotency. */
  applied: boolean;
  reason?: 'already-charged' | 'no-bookings' | 'free-trip';
}

const PRICING_COUNTRY = 'JO';

@Injectable()
export class DriverTripFeeService {
  private readonly logger = new Logger(DriverTripFeeService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(WalletAccountEntity)
    private readonly walletAccountRepo: Repository<WalletAccountEntity>,
    @InjectRepository(WalletTransactionEntity)
    private readonly walletTxRepo: Repository<WalletTransactionEntity>,
    @InjectRepository(PendingChargeEntity)
    private readonly pendingChargeRepo: Repository<PendingChargeEntity>,
    private readonly dataSource: DataSource,
    private readonly walletService: WalletService,
    private readonly pendingCharges: PendingChargesService,
    private readonly platformPricing: PlatformPricingService,
  ) {}

  /**
   * Fee = seatPrice * totalSeats * percent%, or the legacy flat amount when the
   * configured percent is zero. Mirrors PlatformPricingService.driverUnlockPricing
   * but accepts a plain basis so it can be quoted before a trip row exists.
   */
  async computeExpectedFee(basis: TripFeeBasis): Promise<TripFeeQuote> {
    const row = await this.platformPricing.getActiveFeeRow(PRICING_COUNTRY);
    const seatPrice = this.round2(Number(basis.seatPrice ?? 0));
    const totalSeats = Number(basis.totalSeats ?? 0);
    const percent = Number(row?.driverUnlockPercent ?? 0);
    const legacyFlat = Number(row?.feeAmount ?? 0);
    const amount =
      percent > 0
        ? this.round2((seatPrice * totalSeats * percent) / 100)
        : this.round2(legacyFlat);

    return {
      amount,
      seatPrice,
      totalSeats,
      percent,
      currency: row?.currency ?? basis.currency ?? 'JOD',
    };
  }

  /**
   * Publish-time guard. The driver must be able to cover the whole fee before
   * the trip goes live, because nothing is reserved between publish and start.
   */
  async assertDriverCanCoverTripFee(
    driverId: string,
    basis: TripFeeBasis,
  ): Promise<TripFeeQuote> {
    const quote = await this.computeExpectedFee(basis);
    const summary = await this.walletService.getWalletSummary(
      driverId,
      WalletAccountType.DRIVER,
    );

    if (summary.balance < quote.amount) {
      throw new ForbiddenException({
        code: ErrorCodes.INSUFFICIENT_BALANCE_FOR_TRIP_FEE,
        message: `رصيد محفظتك (${summary.balance.toFixed(2)}) لا يغطي رسوم الرحلة (${quote.amount.toFixed(2)}). اشحن محفظتك قبل نشر الرحلة.`,
        balance: summary.balance,
        requiredAmount: quote.amount,
        currency: quote.currency,
      });
    }

    return quote;
  }

  /**
   * The one and only debit. Called when the trip flips to IN_PROGRESS.
   *
   * Idempotent at three layers, so a replayed BullMQ job, a reconciliation
   * sweep, or two of them racing cannot double-charge:
   *   1. trip.driverWalletChargeApplied — the cheap in-row stamp;
   *   2. a read of the audit row keyed trip-fee:<tripId>, covering the window
   *      where the ledger committed but the stamp did not;
   *   3. the unique index behind that key, which catches the racing caller who
   *      passed layer 2 before the winner committed. That loser converges on
   *      the winner's row rather than propagating the violation.
   *
   * Never throws for a business reason — not for a lost race, not for a failed
   * stamp, not for a failed shortfall insert. The caller must be able to start
   * the trip regardless. When the debt could not be recorded the trip is left
   * unstamped on purpose, so the sweep comes back and repairs it.
   */
  async chargeAtTripStart(trip: TripEntity): Promise<TripFeeChargeResult> {
    const quote = await this.computeExpectedFee({
      seatPrice: Number(trip.price ?? 0),
      totalSeats: trip.totalSeats ?? 0,
      currency: trip.currency,
    });

    if (trip.driverWalletChargeApplied) {
      return {
        tripId: trip.id,
        charged: Number(trip.capturedFeeAmount ?? 0),
        pendingRemainder: 0,
        currency: quote.currency,
        applied: false,
        reason: 'already-charged',
      };
    }

    // Second idempotency layer, covering the window where the ledger committed
    // but stampTripCharged did not. The audit row's unique idempotencyKey is
    // the durable record that this trip's fee was already processed. Without
    // this read the retry would collide with that unique index inside the
    // transaction and throw, so the trip would never get stamped and every
    // future sweep would retry it forever.
    const existingCharge = await this.walletTxRepo.findOne({
      where: { idempotencyKey: this.tripFeeIdempotencyKey(trip.id) },
    });
    if (existingCharge) {
      return this.convergeOnExistingCharge(
        trip,
        existingCharge,
        quote.currency,
      );
    }

    // The auto-start processor flips confirmed bookings to IN_PROGRESS before
    // calling us, so both statuses count as "someone actually rode".
    const confirmedBookings = await this.bookingRepo.find({
      where: {
        tripId: trip.id,
        status: In([BookingStatus.CONFIRMED, BookingStatus.IN_PROGRESS]),
      },
      select: { id: true },
    });

    const metadataBase = {
      seatPrice: quote.seatPrice,
      totalSeats: quote.totalSeats,
      percent: quote.percent,
      formula: 'seatPrice * totalSeats * percent%',
    };

    const runLedger = async (manager: EntityManager) => {
      const driver = await manager.findOne(UserEntity, {
        where: { id: trip.driverId },
        lock: { mode: 'pessimistic_write' },
      });

      const writeAuditRow = async (
        accountId: string | null,
        amount: number,
        metadata: Record<string, unknown>,
      ) => {
        if (!accountId) return;
        await manager.save(
          WalletTransactionEntity,
          manager.create(WalletTransactionEntity, {
            accountId,
            type: WalletTransactionType.TRIP_DEBIT,
            direction: WalletEntryDirection.DEBIT,
            status: WalletTransactionStatus.POSTED,
            amount: amount.toFixed(2),
            currency: quote.currency,
            referenceType: 'trip',
            referenceId: trip.id,
            idempotencyKey: this.tripFeeIdempotencyKey(trip.id),
            metadata,
          }),
        );
      };

      const lockedAccounts = await manager
        .createQueryBuilder(WalletAccountEntity, 'wa')
        .setLock('pessimistic_write')
        .where('wa.userId = :userId', { userId: trip.driverId })
        .andWhere('wa.accountType = :accountType', {
          accountType: WalletAccountType.DRIVER,
        })
        .orderBy('wa.id', 'ASC')
        .getMany();
      const account = pickPrimaryWalletLedgerAccount(lockedAccounts);

      if (confirmedBookings.length === 0) {
        await writeAuditRow(account?.id ?? null, 0, {
          ...metadataBase,
          reason: 'no-bookings',
        });
        return { charged: 0, remainder: 0, reason: 'no-bookings' as const };
      }

      if (driver && !driver.hasUsedLifetimeFreeTrip) {
        driver.hasUsedLifetimeFreeTrip = true;
        await manager.save(UserEntity, driver);
        await writeAuditRow(account?.id ?? null, 0, {
          ...metadataBase,
          freeTripApplied: true,
          discountPercent: 100,
        });
        return { charged: 0, remainder: 0, reason: 'free-trip' as const };
      }

      if (!account) {
        // No ledger row means no audit row can be written (accountId is NOT
        // NULL), so a retry could not be deduplicated. Recording a charge here
        // would double-record on the next sweep, so we record nothing and
        // shout instead.
        this.logger.error(
          `Trip ${trip.id}: driver ${trip.driverId} has no DRIVER wallet account; ` +
            `fee of ${quote.amount.toFixed(2)} ${quote.currency} could not be charged`,
        );
        return { charged: 0, remainder: 0, reason: undefined };
      }

      const available = Math.max(Number(account.balance), 0);
      const charged = this.round2(Math.min(available, quote.amount));
      const remainder = this.round2(quote.amount - charged);

      if (charged > 0) {
        account.balance = this.round2(
          Number(account.balance) - charged,
        ).toFixed(2);
        await manager.save(WalletAccountEntity, account);
        await this.walletService.syncUserLegacyWalletMirror(
          trip.driverId,
          WalletAccountType.DRIVER,
          manager,
        );
      }

      // Written on every outcome, including charged === 0 against an empty
      // wallet. This row is the idempotency record, so it must exist even when
      // no money moved — otherwise a retried sweep finds nothing, re-runs, and
      // records the shortfall as a second pending charge.
      await writeAuditRow(account.id, charged, {
        ...metadataBase,
        feeAmount: quote.amount,
        shortfall: remainder,
      });

      return { charged, remainder, reason: undefined };
    };

    let outcome: {
      charged: number;
      remainder: number;
      reason?: 'no-bookings' | 'free-trip';
    };
    try {
      outcome = await this.dataSource.transaction(runLedger);
    } catch (err) {
      // Layer 3: a concurrent caller passed the guard above before the winner
      // committed, and lost on the unique index. The rollback already undid
      // this side's balance mutation, so converge on the winner's row.
      const winner = this.isDuplicateKeyError(err)
        ? await this.walletTxRepo.findOne({
            where: { idempotencyKey: this.tripFeeIdempotencyKey(trip.id) },
          })
        : null;
      if (!winner) throw err;
      this.logger.warn(
        `Trip ${trip.id} fee: lost the race to a concurrent charge, converging on the committed row`,
      );
      return this.convergeOnExistingCharge(trip, winner, quote.currency);
    }

    // Only stamp once the debt is safely on file. If the insert failed, leaving
    // the trip unstamped is what brings the sweep back to repair it.
    const debtRecorded = await this.settleShortfall(trip, outcome.remainder);
    if (debtRecorded) {
      await this.stampTripCharged(trip, outcome.charged);
    }

    this.logger.log(
      `Trip ${trip.id} fee: charged ${outcome.charged.toFixed(2)} ${quote.currency}` +
        (outcome.remainder > 0
          ? `, ${outcome.remainder.toFixed(2)} carried forward`
          : '') +
        (outcome.reason ? ` (${outcome.reason})` : ''),
    );

    return {
      tripId: trip.id,
      charged: outcome.charged,
      pendingRemainder: outcome.remainder,
      currency: quote.currency,
      applied: true,
      reason: outcome.reason,
    };
  }

  /**
   * Audit stamp. These columns no longer gate anything — they record when and
   * how much the platform took, and the admin dashboard reads them.
   *
   * Deliberately outside the ledger transaction: if the stamp fails, the
   * reconciliation sweep re-runs the charge, and the idempotencyKey on the
   * audit row plus the balance check keep that safe.
   */
  private async stampTripCharged(
    trip: TripEntity,
    charged: number,
  ): Promise<void> {
    const now = new Date();
    trip.driverWalletChargeApplied = true;
    trip.driverWalletChargeAt = now;
    trip.communicationFeeStatus = 'paid';
    trip.capturedFeeAmount = charged.toFixed(2);

    try {
      await this.tripRepo.save(trip);
      await this.bookingRepo.update(
        {
          tripId: trip.id,
          status: In([
            BookingStatus.PENDING,
            BookingStatus.CONFIRMED,
            BookingStatus.IN_PROGRESS,
          ]),
        },
        { hasDriverPaidToContact: true },
      );
    } catch (err) {
      // The money is already correct and the trip must be able to start, so
      // this never propagates. Roll the in-memory flags back so a caller that
      // saves this entity later does not persist a stamp the DB rejected; the
      // sweep re-reads the trip and converges on the audit row.
      trip.driverWalletChargeApplied = false;
      trip.driverWalletChargeAt = null;
      this.logger.error(
        `Trip ${trip.id}: fee captured but the audit stamp failed — reconciliation will retry: ${(err as Error).message}`,
      );
    }
  }

  /**
   * Converge on an audit row this trip already has: move no money, make sure
   * the shortfall it recorded is still owed somewhere, and stamp the trip.
   */
  private async convergeOnExistingCharge(
    trip: TripEntity,
    existing: WalletTransactionEntity,
    currency: string,
  ): Promise<TripFeeChargeResult> {
    const charged = Number(existing.amount ?? 0);
    const shortfall = this.round2(Number(existing.metadata?.shortfall ?? 0));

    // The ledger and the PendingCharge insert are not atomic with each other,
    // so a crash between them leaves a debt with nothing to collect it. The
    // audit row's shortfall is the only surviving evidence — re-record it.
    if (await this.settleShortfall(trip, shortfall)) {
      await this.stampTripCharged(trip, charged);
    }

    return {
      tripId: trip.id,
      charged,
      pendingRemainder: shortfall,
      currency,
      applied: false,
      reason: 'already-charged',
    };
  }

  /**
   * Puts the shortfall on file exactly once. Returns false when it could not
   * be recorded, which tells the caller to leave the trip unstamped so the
   * reconciliation sweep comes back for it.
   */
  private async settleShortfall(
    trip: TripEntity,
    amount: number,
  ): Promise<boolean> {
    if (amount <= 0) return true;
    try {
      // PendingChargesService.record has no dedupe of its own, so the
      // existence check has to live here.
      const existing = await this.pendingChargeRepo.findOne({
        where: { tripId: trip.id, kind: PendingChargeKind.DRIVER_TRIP_FEE },
      });
      if (!existing) {
        await this.pendingCharges.record({
          userId: trip.driverId,
          kind: PendingChargeKind.DRIVER_TRIP_FEE,
          amount,
          tripId: trip.id,
        });
      }
      return true;
    } catch (err) {
      this.logger.error(
        `Trip ${trip.id}: could not record the ${amount.toFixed(2)} shortfall, ` +
          `leaving the trip unstamped so reconciliation repairs it: ${(err as Error).message}`,
      );
      return false;
    }
  }

  /** Postgres unique-violation, however TypeORM happens to wrap it. */
  private isDuplicateKeyError(err: unknown): boolean {
    const e = err as { code?: string; driverError?: { code?: string } };
    if ((e?.driverError?.code ?? e?.code) === '23505') return true;
    const message = (err as Error)?.message ?? '';
    return (
      message.includes('duplicate key value') ||
      message.includes('wallet_tx_idempotency_idx')
    );
  }

  /** One audit row per trip; this key is the durable idempotency guard. */
  private tripFeeIdempotencyKey(tripId: string): string {
    return `trip-fee:${tripId}`;
  }

  private round2(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }
}
