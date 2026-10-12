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

  it("driverUnlockPricing charges a percent fee in the trip's currency", () => {
    const trip = {
      price: '40',
      totalSeats: 4,
      currency: 'SAR',
    } as unknown as TripEntity;
    const row = {
      driverUnlockPercent: 10,
      feeAmount: 0,
      currency: 'JOD',
    } as CommunicationFeeEntity;
    const u = svc.driverUnlockPricing(trip, row);
    expect(u.feeAmount).toBe(16);
    expect(u.currency).toBe('SAR');
  });

  describe('getFeeRowForCurrency', () => {
    const rows: Record<string, Partial<CommunicationFeeEntity>> = {
      JO: { countryCode: 'JO', isActive: true, driverUnlockPercent: 10 },
      SA: { countryCode: 'SA', isActive: true, driverUnlockPercent: 5 },
      AE: { countryCode: 'AE', isActive: false, driverUnlockPercent: 7 },
    };
    const repo = {
      findOne: jest.fn(
        async ({ where }: any) =>
          (rows[where.countryCode] &&
          (where.isActive === undefined ||
            rows[where.countryCode].isActive === where.isActive)
            ? rows[where.countryCode]
            : null) ?? null,
      ),
    };
    const pricing = new PlatformPricingService(repo as any);

    it("uses the currency's own country schedule", async () => {
      await expect(pricing.getFeeRowForCurrency('SAR')).resolves.toBe(rows.SA);
    });

    it("falls back to Jordan's schedule for a country without one", async () => {
      await expect(pricing.getFeeRowForCurrency('QAR')).resolves.toBe(rows.JO);
      await expect(pricing.getFeeRowForCurrency(null)).resolves.toBe(rows.JO);
    });

    it('charges nothing in a country whose schedule is switched off', async () => {
      await expect(pricing.getFeeRowForCurrency('AED')).resolves.toBeNull();
    });
  });
});
