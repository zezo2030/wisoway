import { PlatformPricingService } from './platform-pricing.service';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';

describe('PlatformPricingService', () => {
  const svc = new PlatformPricingService(null as any);

  it('passengerSeatPricing splits seat price by percent', () => {
    const row = {
      passengerPlatformPercent: 15,
    } as CommunicationFeeEntity;
    const r = svc.passengerSeatPricing(200, 'JOD', row);
    expect(r.platformAmount).toBe(30);
    expect(r.driverAmount).toBe(170);
    expect(r.requiresOnlinePayment).toBe(true);
  });

  it('passengerSeatPricing with zero percent skips online payment', () => {
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
