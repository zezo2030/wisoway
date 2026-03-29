import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';

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

  round2(n: number): number {
    return Math.round(n * 100) / 100;
  }

  passengerSeatPricing(
    seatPrice: number,
    currency: string,
    row: CommunicationFeeEntity | null,
  ): PassengerSeatPricing {
    const pct = Number(row?.passengerPlatformPercent ?? 0);
    const platformAmount = this.round2((seatPrice * pct) / 100);
    const driverAmount = this.round2(seatPrice - platformAmount);
    return {
      seatPrice: this.round2(seatPrice),
      passengerPlatformPercent: pct,
      platformAmount,
      driverAmount,
      currency,
      requiresOnlinePayment: platformAmount > 0,
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
    const pct = Number(row?.driverUnlockPercent ?? 0);
    const legacyFlat = Number(row?.feeAmount ?? 0);
    const currency = row?.currency ?? trip.currency ?? 'EGP';
    const feeAmount =
      pct > 0
        ? this.round2((seatPrice * totalSeats * pct) / 100)
        : this.round2(legacyFlat);
    return {
      feeAmount,
      currency,
      driverUnlockPercent: pct,
      legacyFlatFeeAmount: legacyFlat,
      seatPrice: this.round2(seatPrice),
      totalSeats,
    };
  }

  async pricingPreviewForTrip(
    trip: TripEntity,
    countryCode: string = 'EG',
  ): Promise<{
    tripId: string;
    passenger: PassengerSeatPricing;
    driverUnlock: DriverUnlockPricing;
  }> {
    const row = await this.getActiveFeeRow(countryCode);
    const passenger = this.passengerSeatPricing(
      Number(trip.price ?? 0),
      trip.currency ?? 'EGP',
      row,
    );
    const driverUnlock = this.driverUnlockPricing(trip, row);
    return { tripId: trip.id, passenger, driverUnlock };
  }
}
