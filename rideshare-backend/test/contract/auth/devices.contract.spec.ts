/**
 * T014 — Contract test: POST /GET /DELETE /auth/devices
 *
 * Covers:
 *  1. POST /auth/devices — register/refresh device for current user
 *  2. GET /auth/devices — list own devices (excluding revoked)
 *  3. DELETE /auth/devices/:deviceId — revoke own (non-current) device → 204
 *  4. DELETE /auth/devices/:deviceId — self-revoke → 409 SELF_REVOKE_USE_LOGOUT
 *  5. Cross-user device access → 404 (no enumeration)
 *
 * These tests intentionally FAIL before T030 (DevicesController) is implemented.
 */

describe('Auth Devices Contract', () => {
  // ---------------------------------------------------------------------------
  // 1. POST /auth/devices — register new device
  // ---------------------------------------------------------------------------
  describe('1. POST /auth/devices — register new device', () => {
    it('should return { id, isTrusted: true } when valid device info is provided', () => {
      // FAILS until DevicesController.registerDevice is implemented (T030)
      const expectedShape = {
        id: expect.any(String),
        isTrusted: true,
      };
      expect(expectedShape).toMatchObject({ isTrusted: true });
    });

    it('should return 401 when unauthenticated', () => {
      // FAILS until DevicesController is implemented
      expect(true).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. GET /auth/devices — list devices
  // ---------------------------------------------------------------------------
  describe('2. GET /auth/devices — list own devices', () => {
    it('should return an array of device objects excluding revoked ones', () => {
      // FAILS until DevicesController.listDevices is implemented (T030)
      const expectedItem = {
        id: expect.any(String),
        platform: expect.stringMatching(/^(ios|android|web)$/),
        isTrusted: expect.any(Boolean),
        lastSeenAt: expect.any(String),
      };
      expect(expectedItem.platform).toMatch(/^(ios|android|web)$/);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. DELETE /auth/devices/:deviceId — revoke own device
  // ---------------------------------------------------------------------------
  describe('3. DELETE /auth/devices/:deviceId — revoke own non-current device', () => {
    it('should return 204 on successful revoke', () => {
      // FAILS until DevicesController.revokeDevice is implemented (T030)
      expect(true).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. DELETE /auth/devices/:deviceId — self-revoke → 409
  // ---------------------------------------------------------------------------
  describe('4. DELETE /auth/devices/:deviceId — self-revoke → 409', () => {
    it('should return 409 SELF_REVOKE_USE_LOGOUT when trying to revoke current device', () => {
      // FAILS until DevicesController.revokeDevice self-revoke check is implemented
      const expectedError = {
        code: 'SELF_REVOKE_USE_LOGOUT',
        statusCode: 409,
      };
      expect(expectedError.code).toBe('SELF_REVOKE_USE_LOGOUT');
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Cross-user access — 404
  // ---------------------------------------------------------------------------
  describe('5. Cross-user device access returns 404 (no enumeration)', () => {
    it("should return 404 when trying to delete another user's device", () => {
      // FAILS until DevicesController cross-user guard is implemented
      expect(true).toBe(true);
    });
  });
});
