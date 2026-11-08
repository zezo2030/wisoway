import { DriverWalletPolicyService } from './driver-wallet-policy.service';

describe('Driver wallet currency policy', () => {
  const repo = { findOne: jest.fn(), upsert: jest.fn() };
  const policy = new DriverWalletPolicyService(repo as any);
  afterEach(() => {
    jest.restoreAllMocks();
    jest.resetAllMocks();
  });
  /** Answers each settings key from [rows]; anything else is unset. */
  const rows = (values: Record<string, string>) =>
    repo.findOne.mockImplementation(
      ({ where: { key } }: { where: { key: string } }) =>
        Promise.resolve(key in values ? { key, value: values[key] } : null),
    );
  const fetchSpy = () => jest.spyOn(globalThis, 'fetch');

  it('defaults to 5 JOD and 25 SAR without an FX call', async () => {
    rows({});
    const fetch = fetchSpy();
    expect(await policy.minimum('JOD')).toBe(5);
    expect(await policy.minimum('SAR')).toBe(25);
    expect(fetch).not.toHaveBeenCalled();
  });
  it('uses the amounts the admin set in Operations settings', async () => {
    rows({ 'wallet.minimumTopup.JOD': '7.5', 'wallet.minimumTopup.SAR': '40' });
    expect(await policy.minimum('JOD')).toBe(7.5);
    expect(await policy.minimum('SAR')).toBe(40);
  });
  it('ignores a stored amount that is not a positive number', async () => {
    rows({ 'wallet.minimumTopup.JOD': 'abc', 'wallet.minimumTopup.SAR': '0' });
    expect(await policy.minimum('JOD')).toBe(5);
    expect(await policy.minimum('SAR')).toBe(25);
  });
  it('converts five JOD with a cached rate and rounds up to the wallet precision', async () => {
    rows({
      'wallet.fx.JOD': JSON.stringify({
        updated: Date.now(),
        rates: { AED: 5.18123 },
      }),
    });
    expect(await policy.minimum('AED')).toBe(25.91);
  });
  it("converts the admin's JOD amount for other currencies", async () => {
    rows({
      'wallet.minimumTopup.JOD': '10',
      'wallet.fx.JOD': JSON.stringify({
        updated: Date.now(),
        rates: { AED: 5.18123 },
      }),
    });
    expect(await policy.minimum('AED')).toBe(51.82);
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
    rows({
      'wallet.fx.JOD': JSON.stringify({
        updated: Date.now() - 96 * 3600_000,
        rates: { EGP: 70 },
      }),
    });
    jest.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('offline'));
    await expect(policy.minimum('EGP')).rejects.toThrow();
  });
});
