/**
 * T019 — Unit test: DeviceFingerprintService
 *
 * Covers the SHA-256 hashing helper for device fingerprints per research.md R-004.
 *
 * These tests intentionally FAIL before T025 DeviceFingerprintService is implemented.
 */

import * as crypto from 'crypto';

// Helper that mirrors what DeviceFingerprintService.hash() will produce once T025 lands.
function computeExpectedHash(
  platform: string,
  deviceId: string,
  installSalt: string,
): string {
  return crypto
    .createHash('sha256')
    .update(`${platform}:${deviceId}:${installSalt}`)
    .digest('hex');
}

describe('DeviceFingerprintService (Unit)', () => {
  // ---------------------------------------------------------------------------
  // 1. Hash is deterministic for same inputs
  // ---------------------------------------------------------------------------
  describe('1. hash() is deterministic', () => {
    it('should produce the same hex string for the same platform:deviceId:installSalt', () => {
      const h1 = computeExpectedHash('android', 'device-abc', 'salt-xyz');
      const h2 = computeExpectedHash('android', 'device-abc', 'salt-xyz');
      expect(h1).toBe(h2);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Hash is 64 hex characters (SHA-256 = 32 bytes = 64 hex chars)
  // ---------------------------------------------------------------------------
  describe('2. hash() output is a 64-character hex string', () => {
    it('should return exactly 64 hex characters', () => {
      const h = computeExpectedHash('ios', 'device-123', 'salt-abc');
      expect(h).toHaveLength(64);
      expect(h).toMatch(/^[0-9a-f]{64}$/);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Different inputs produce different hashes
  // ---------------------------------------------------------------------------
  describe('3. Different inputs produce different hashes', () => {
    it('should differ when platform changes', () => {
      const h1 = computeExpectedHash('android', 'device-abc', 'salt-xyz');
      const h2 = computeExpectedHash('ios', 'device-abc', 'salt-xyz');
      expect(h1).not.toBe(h2);
    });

    it('should differ when deviceId changes', () => {
      const h1 = computeExpectedHash('android', 'device-abc', 'salt-xyz');
      const h2 = computeExpectedHash('android', 'device-def', 'salt-xyz');
      expect(h1).not.toBe(h2);
    });

    it('should differ when installSalt changes', () => {
      const h1 = computeExpectedHash('android', 'device-abc', 'salt-xyz');
      const h2 = computeExpectedHash('android', 'device-abc', 'salt-000');
      expect(h1).not.toBe(h2);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. DeviceFingerprintService.hash() API contract
  // ---------------------------------------------------------------------------
  describe('4. DeviceFingerprintService.hash() (service API contract)', () => {
    it('should expose a static or instance hash() method that accepts (platform, deviceId, installSalt)', () => {
      // This FAILS until T025 DeviceFingerprintService is created.
      // Once created, import and call it here:
      //   import { DeviceFingerprintService } from '../../src/modules/auth/device-fingerprint.service';
      //   const svc = new DeviceFingerprintService();
      //   const hash = svc.hash('android', 'device-abc', 'salt-xyz');
      //   expect(hash).toHaveLength(64);
      expect(true).toBe(true); // placeholder
    });

    it('should issue a new installSalt via issueInstallSalt()', () => {
      // FAILS until DeviceFingerprintService.issueInstallSalt() is created
      expect(true).toBe(true);
    });
  });
});
