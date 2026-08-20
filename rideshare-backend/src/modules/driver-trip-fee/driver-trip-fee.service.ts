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
import { DataSource, In, Repository } from 'typeorm';
import {
  BookingEntity,
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
   * Idempotent by trip.driverWalletChargeApplied, so a replayed BullMQ job or a
   * reconciliation sweep cannot double-charge. Never throws for a business
   * reason — the caller must be able to start the trip regardless.
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

    const outcome = await this.dataSource.transaction(async (manager) => {
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
            idempotencyKey: `trip-fee:${trip.id}`,
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
        return { charged: 0, remainder: quote.amount, reason: undefined };
      }

      const available = Math.max(Number(account.balance), 0);
      const charged = this.round2(Math.min(available, quote.amount));
      const remainder = this.round2(quote.amount - charged);

      if (charged > 0) {
        account.balance = this.round2(
          Number(account.balance) - charged,
        ).toFixed(2);
        await manager.save(WalletAccountEntity, account);
        await writeAuditRow(account.id, charged, {
          ...metadataBase,
          feeAmount: quote.amount,
          shortfall: remainder,
        });
        await this.walletService.syncUserLegacyWalletMirror(
          trip.driverId,
          WalletAccountType.DRIVER,
          manager,
        );
      }

      return { charged, remainder, reason: undefined };
    });

    if (outcome.remainder > 0) {
      await this.pendingCharges.record({
        userId: trip.driverId,
        kind: PendingChargeKind.DRIVER_TRIP_FEE,
        amount: outcome.remainder,
        tripId: trip.id,
      });
    }

    await this.stampTripCharged(trip, outcome.charged);

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
  }

  private round2(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }
}
