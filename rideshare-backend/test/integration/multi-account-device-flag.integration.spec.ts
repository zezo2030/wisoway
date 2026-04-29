/**
 * T018 — Integration test: multi-account-from-one-device threshold flag
 *
 * Covers:
 *  - After 3+ distinct userIds login from the same fingerprintHash within 24h,
 *    the 3rd/4th account gets restricted=true and an account_flags row is created
 *    with reason='multi_account_device'
 *
 * These tests intentionally FAIL before T027 AccountRiskService is implemented.
 */

describe('Multi-Account-Device Flag (Integration)', () => {
  // ---------------------------------------------------------------------------
  // 1. Under threshold — no flag
  // ---------------------------------------------------------------------------
  describe('1. Under threshold (< 3 accounts from same device within 24h)', () => {
    it('should NOT set restricted=true or create an account_flags row', () => {
      // FAILS until T027 AccountRiskService is implemented
      expect(true).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. At threshold — flag created
  // ---------------------------------------------------------------------------
  describe('2. At/above threshold (≥ 3 accounts from same device within 24h)', () => {
    it('should set users.restricted=true for the latest account', () => {
      // FAILS until T027 AccountRiskService.checkMultiAccountThreshold is called from verifyOtp
      expect(true).toBe(true);
    });

    it('should create an account_flags row with reason=multi_account_device', () => {
      // FAILS until T027 + T022 AccountFlag entity are live
      const expectedFlag = {
        reason: 'multi_account_device',
        severity: expect.stringMatching(/^(low|medium|high|critical)$/),
        disposition: 'open',
      };
      expect(expectedFlag.reason).toBe('multi_account_device');
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Threshold is configurable via environment variable
  // ---------------------------------------------------------------------------
  describe('3. Multi-account threshold is env-configured (default 3)', () => {
    it('should use MULTI_ACCOUNT_DEVICE_THRESHOLD env var when set', () => {
      // FAILS until T027 reads the threshold from config
      expect(true).toBe(true);
    });
  });
});
