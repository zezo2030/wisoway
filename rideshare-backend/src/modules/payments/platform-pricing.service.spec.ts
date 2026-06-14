import { PlatformPricingService } from './platform-pricing.service';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';

describe('PlatformPricingService', () => {
  const svc = new PlatformPricingService(null as any);

  it('passengerSeatPricing always sends the full price to the driver as cash', () => {
    // Passenger platform fee was removed — the row's percent is intentionally
    // ignored and no online payment is ever required from the rider.
    const row = {
      passengerPlatformPercent: 15,
    } as CommunicationFeeEntity;
    const r = svc.passengerSeatPricing(200, 'JOD', row);
    expect(r.platformAmount).toBe(0);
    expect(r.driverAmount).toBe(200);
    expect(r.requiresOnlinePayment).toBe(false);
  });

  it('passengerSeatPricing with no fee row also skips online payment', () => {
    const r = svc.passengerSeatPricing(200, 'JOD', null);
    expect(r.platformAmount).toBe(0);
    expect(r.driverAmount).toBe(200);
    expect(r.requiresOnlinePayment).toBe(false);
  });

  it('driverUnlockPricing uses percent of seat × seats when pct > 0', () => {
    const trip = {
      price: '50',
      totalSeats: 4,
      currency: 'JOD',
    } as unknown as TripEntity;
    const row = {
      driverUnlockPercent: 10,
      feeAmount: 999,
      currency: 'JOD',
    } as CommunicationFeeEntity;
    const u = svc.driverUnlockPricing(trip, row);
    expect(u.feeAmount).toBe(20);
  });

  it('driverUnlockPricing falls back to flat fee when percent is 0', () => {
    const trip = {
      price: '50',
      totalSeats: 4,
      currency: 'JOD',
    } as unknown as TripEntity;
    const row = {
      driverUnlockPercent: 0,
      feeAmount: 25,
      currency: 'JOD',
    } as CommunicationFeeEntity;
    const u = svc.driverUnlockPricing(trip, row);
    expect(u.feeAmount).toBe(25);
  });
});
