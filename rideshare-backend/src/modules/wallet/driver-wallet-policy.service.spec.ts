import { DriverWalletPolicyService } from './driver-wallet-policy.service';

describe('Driver wallet currency policy', () => {
  const repo = { findOne: jest.fn(), upsert: jest.fn() };
  const policy = new DriverWalletPolicyService(repo as any);
  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
  });
  it('keeps the explicitly requested JOD/SAR amounts without an FX call', async () => {
    expect(await policy.minimum('JOD')).toBe(5);
    expect(await policy.minimum('SAR')).toBe(25);
    expect(repo.findOne).not.toHaveBeenCalled();
  });
  it('converts five JOD with a cached rate and rounds up to the wallet precision', async () => {
    repo.findOne.mockResolvedValue({
      value: JSON.stringify({ updated: Date.now(), rates: { AED: 5.18123 } }),
    });
    expect(await policy.minimum('AED')).toBe(25.91);
  });
  it('fetches and persists a validated current JOD rate', async () => {
    repo.findOne.mockResolvedValue(null);
    jest.spyOn(globalThis, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({
        result: 'success',
        base_code: 'JOD',
        time_last_update_unix: Math.floor(Date.now() / 1000),
        rates: { EGP: 70 },
      }),
    } as Response);
    expect(await policy.minimum('EGP')).toBe(350);
    expect(repo.upsert).toHaveBeenCalled();
  });
  it('refuses stale/unavailable rates rather than granting an invented amount', async () => {
    repo.findOne.mockResolvedValue({
      value: JSON.stringify({
        updated: Date.now() - 96 * 3600_000,
        rates: { EGP: 70 },
      }),
    });
    jest.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('offline'));
    await expect(policy.minimum('EGP')).rejects.toThrow();
  });
});
