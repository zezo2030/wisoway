import { DriverTripFeeService } from './driver-trip-fee.service';

describe('DriverTripFeeService revenue model', () => {
  const wallet = {
    commissionPercent: jest.fn().mockResolvedValue(10),
    assertNonNegativeDriverBalance: jest.fn().mockResolvedValue(undefined),
    getBalanceIn: jest.fn().mockResolvedValue(1),
    chargeCompletedTripCommission: jest.fn().mockResolvedValue({ charged: 1 }),
  };
  const service = new DriverTripFeeService(wallet as any);
  beforeEach(() => jest.clearAllMocks());
  it('quotes the entire instant fare once using its own commission rate', async () => {
    wallet.commissionPercent.mockResolvedValueOnce(15);
    const quote = await service.computeExpectedFee({
      seatPrice: 10,
      totalSeats: 4,
      tripType: 'instant',
    });
    expect(quote.amount).toBe(1.5);
    expect(wallet.commissionPercent).toHaveBeenCalledWith('instant');
  });
  it('never charges at trip start', async () => {
    await service.chargeAtTripStart({
      id: 't',
      status: 'in_progress',
      currency: 'JOD',
    } as any);
    expect(wallet.chargeCompletedTripCommission).not.toHaveBeenCalled();
  });
  it('delegates completed trips to the atomic commission ledger', async () => {
    await service.chargeAtTripStart({ id: 't', status: 'completed' } as any);
    expect(wallet.chargeCompletedTripCommission).toHaveBeenCalledWith('t');
  });
  it('allows creation while credit remains, without requiring the projected capacity fee', async () => {
    const quote = await service.assertDriverCanCoverTripFee('d', {
      seatPrice: 10,
      totalSeats: 4,
      currency: 'JOD',
    });
    expect(quote.amount).toBe(4);
    expect(wallet.assertNonNegativeDriverBalance).toHaveBeenCalledWith(
      'd',
      'JOD',
    );
  });
  it('refuses creation when the trip currency has no credit', async () => {
    wallet.getBalanceIn.mockResolvedValueOnce(0);
    await expect(
      service.assertDriverCanCoverTripFee('d', {
        seatPrice: 10,
        totalSeats: 4,
      }),
    ).rejects.toThrow();
  });
});
