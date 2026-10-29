import { InstantMeterService } from './instant-meter.service';
import { fareTariffFor } from './instant-rides.constants';

/** A trip started at [startedAt] after waiting [waitedMin] at the pickup. */
function trip(startedAt: Date, waitedMin = 0, currency = 'JOD'): any {
  return {
    id: 't1',
    currency,
    price: '9.99',
    tripStartedAt: startedAt,
    driverArrivedAt: new Date(startedAt.getTime() - waitedMin * 60_000),
  };
}

describe('InstantMeterService', () => {
  const start = new Date('2026-10-21T08:00:00Z');
  let path: { lat: number; lng: number }[];
  let tripRepo: any;
  let bookingRepo: any;
  let service: InstantMeterService;

  beforeEach(() => {
    path = [];
    tripRepo = {
      query: jest.fn(() => Promise.resolve(path)),
      update: jest.fn().mockResolvedValue({}),
    };
    bookingRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: 'b1',
        seatCount: 1,
        discountAmount: '0.00',
      }),
      update: jest.fn().mockResolvedValue({}),
    };
    const tariffs = {
      tariffFor: jest.fn((c: string) => Promise.resolve(fareTariffFor(c))),
    };
    service = new InstantMeterService(tripRepo, bookingRepo, tariffs as any);
  });

  it('charges only the minimum for a ride started and ended at once', async () => {
    const result = await service.settle(trip(start), start);

    expect(result?.distanceKm).toBe(0);
    expect(result?.fare).toBe(fareTariffFor('JOD').minimum);
    expect(bookingRepo.update).toHaveBeenCalledWith(
      { id: 'b1' },
      expect.objectContaining({ totalAmount: '1.25', originalAmount: '1.25' }),
    );
  });

  it('prices the road actually driven, not the estimate', async () => {
    // ~11.1 km due north along the tracked path.
    path = [
      { lat: 31.9, lng: 35.9 },
      { lat: 31.95, lng: 35.9 },
      { lat: 32.0, lng: 35.9 },
    ];
    const end = new Date(start.getTime() + 20 * 60_000);

    const result = await service.settle(trip(start), end);

    expect(result?.distanceKm).toBeCloseTo(11.12, 1);
    // JOD: 0.45 + 11.12 × 0.316 = 3.96 → 4.00 at the 0.05 step
    expect(result?.fare).toBe(4);
    expect(tripRepo.update).toHaveBeenCalledWith(
      { id: 't1' },
      { price: '4.00' },
    );
  });

  it('adds the wait at the pickup past the free minutes', async () => {
    const result = await service.settle(trip(start, 6), start);

    // 6 minutes waited, 3 free → 3 × 0.065
    expect(result?.waitingCharge).toBe(0.2);
    expect(result?.fare).toBe(1.45);
  });

  it('keeps a promo discount off the metered fare', async () => {
    bookingRepo.findOne.mockResolvedValue({
      id: 'b1',
      seatCount: 1,
      discountAmount: '0.50',
    });

    await service.settle(trip(start), start);

    expect(bookingRepo.update).toHaveBeenCalledWith(
      { id: 'b1' },
      expect.objectContaining({ originalAmount: '1.25', totalAmount: '0.75' }),
    );
  });

  it('leaves a ride that never started alone', async () => {
    expect(
      await service.settle({ ...trip(start), tripStartedAt: null }, start),
    ).toBeNull();
    expect(bookingRepo.update).not.toHaveBeenCalled();
  });
});
