import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import {
  DEFAULT_CURRENCY,
  countryForCurrency,
} from '../../common/currency/country-currency';

/** Country whose fee schedule applies where no country has its own. */
export const DEFAULT_PRICING_COUNTRY = 'JO';

export interface PassengerSeatPricing {
  seatPrice: number;
  passengerPlatformPercent: number;
  platformAmount: number;
  driverAmount: number;
  currency: string;
  requiresOnlinePayment: boolean;
}

export interface DriverUnlockPricing {
  feeAmount: number;
  currency: string;
  driverUnlockPercent: number;
  legacyFlatFeeAmount: number;
  seatPrice: number;
  totalSeats: number;
}

@Injectable()
export class PlatformPricingService {
  constructor(
    @InjectRepository(CommunicationFeeEntity)
    private readonly communicationFeeRepo: Repository<CommunicationFeeEntity>,
  ) {}

  async getActiveFeeRow(
    countryCode: string,
  ): Promise<CommunicationFeeEntity | null> {
    return this.communicationFeeRepo.findOne({
      where: { countryCode, isActive: true },
    });
  }

  /**
   * Fee schedule for trips priced in [currency]: the row of the country that
   * currency belongs to. A country with no row of its own uses Jordan's (the
   * default schedule); a country whose row is switched off charges nothing.
   */
  async getFeeRowForCurrency(
    currency?: string | null,
  ): Promise<CommunicationFeeEntity | null> {
    const countryCode = countryForCurrency(currency) ?? DEFAULT_PRICING_COUNTRY;
    const own = await this.communicationFeeRepo.findOne({
      where: { countryCode },
    });
    if (own) return own.isActive ? own : null;
    return this.getActiveFeeRow(DEFAULT_PRICING_COUNTRY);
  }

  /**
   * Driver fee in the trip's own [currency]: seatPrice × totalSeats × percent
   * when a percent is set (currency-neutral, so any country's row applies);
   * otherwise the row's flat amount, but only when that row is priced in the
   * same currency — a flat JOD amount is never charged as riyals.
   */
  driverFee(
    seatPrice: number,
    totalSeats: number,
    currency: string | null | undefined,
    row: CommunicationFeeEntity | null,
  ): { amount: number; percent: number; legacyFlat: number; currency: string } {
    const percent = Number(row?.driverUnlockPercent ?? 0);
    const feeCurrency = currency || row?.currency || DEFAULT_CURRENCY;
    const legacyFlat =
      row && row.currency === feeCurrency ? Number(row.feeAmount ?? 0) : 0;
    const amount =
      percent > 0
        ? this.round2((seatPrice * totalSeats * percent) / 100)
        : this.round2(legacyFlat);
    return { amount, percent, legacyFlat, currency: feeCurrency };
  }

  round2(n: number): number {
    return Math.round(n * 100) / 100;
  }

  passengerSeatPricing(
    seatPrice: number,
    currency: string,
    _row: CommunicationFeeEntity | null,
  ): PassengerSeatPricing {
    // Passengers no longer pay any platform fee. The full seat price is owed
    // to the driver in cash on meet-up; the app is not in the rider's payment
    // path at all. The communication-fee table still drives driverUnlockPricing
    // separately (kept untouched).
    const price = this.round2(seatPrice);
    return {
      seatPrice: price,
      passengerPlatformPercent: 0,
      platformAmount: 0,
      driverAmount: price,
      currency,
      requiresOnlinePayment: false,
    };
  }

  /**
   * If driverUnlockPercent > 0: fee = seatPrice * totalSeats * (pct/100).
   * Else fallback to legacy flat feeAmount from the same row.
   */
  driverUnlockPricing(
    trip: TripEntity,
    row: CommunicationFeeEntity | null,
  ): DriverUnlockPricing {
    const seatPrice = Number(trip.price ?? 0);
    const totalSeats = trip.totalSeats ?? 0;
    const fee = this.driverFee(seatPrice, totalSeats, trip.currency, row);
    return {
      feeAmount: fee.amount,
      currency: fee.currency,
      driverUnlockPercent: fee.percent,
      legacyFlatFeeAmount: fee.legacyFlat,
      seatPrice: this.round2(seatPrice),
      totalSeats,
    };
  }

  async pricingPreviewForTrip(
    trip: TripEntity,
    countryCode?: string,
  ): Promise<{
    tripId: string;
    passenger: PassengerSeatPricing;
    driverUnlock: DriverUnlockPricing;
  }> {
    const row = countryCode
      ? await this.getActiveFeeRow(countryCode)
      : await this.getFeeRowForCurrency(trip.currency);
    const passenger = this.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'JOD',
      row,
    );
    const driverUnlock = this.driverUnlockPricing(trip, row);
    return { tripId: trip.id, passenger, driverUnlock };
  }
}
