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
import { DataSource, Repository } from 'typeorm';
import {
  BookingEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletTransactionEntity,
} from '../../database/entities';
import { ErrorCodes } from '../../common/errors/error-codes';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { WalletService } from '../wallet/wallet.service';

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

  private round2(value: number): number {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }
}
