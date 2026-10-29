import { ForbiddenException, Injectable } from '@nestjs/common';
import { TripEntity, WalletAccountType } from '../../database/entities';
import { WalletService } from '../wallet/wallet.service';

export interface TripFeeBasis {
  seatPrice: number;
  totalSeats: number;
  currency?: string | null;
  tripType?: string;
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

/** Quotes projected commission; collection uses completed bookings, never capacity. */
@Injectable()
export class DriverTripFeeService {
  constructor(private readonly walletService: WalletService) {}

  async computeExpectedFee(basis: TripFeeBasis): Promise<TripFeeQuote> {
    const percent = await this.walletService.commissionPercent(
      basis.tripType ?? 'shared',
    );
    const seatPrice = Number(basis.seatPrice || 0);
    const totalSeats =
      basis.tripType === 'instant' ? 1 : Number(basis.totalSeats || 0);
    return {
      amount: Math.round(seatPrice * totalSeats * percent) / 100,
      seatPrice,
      totalSeats,
      percent,
      currency: basis.currency || 'JOD',
    };
  }

  async assertDriverCanCoverTripFee(
    driverId: string,
    basis: TripFeeBasis,
  ): Promise<TripFeeQuote> {
    const quote = await this.computeExpectedFee(basis);
    await this.walletService.assertNonNegativeDriverBalance(
      driverId,
      quote.currency,
    );
    const balance = await this.walletService.getBalanceIn(
      driverId,
      WalletAccountType.DRIVER,
      quote.currency,
    );
    if (balance <= 0)
      throw new ForbiddenException('اشحن محفظتك قبل إنشاء الرحلة.');
    return quote;
  }

  // Compatibility entry point for existing start workers. Only completed trips charge.
  async chargeAtTripStart(trip: TripEntity): Promise<TripFeeChargeResult> {
    if (trip.status !== 'completed')
      return {
        tripId: trip.id,
        charged: 0,
        pendingRemainder: 0,
        currency: trip.currency,
        applied: false,
      };
    return this.walletService.chargeCompletedTripCommission(trip.id);
  }
}
