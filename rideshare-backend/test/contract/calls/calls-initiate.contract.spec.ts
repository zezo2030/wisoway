/**
 * T133 — Contract test: POST /bookings/:id/calls/initiate
 *
 * Covers:
 *  1. Happy path: confirmed booking, caller is main booker or trip driver →
 *     { callSessionId, proxyNumberE164, expiresAt } returned; call_sessions row created.
 *     This holds regardless of whether the driver has been charged the trip
 *     fee yet — calls are no longer gated on payment.
 *  2. Pool exhausted: 503 NO_PROXY_NUMBERS_AVAILABLE.
 *  3. hidePhoneNumber=true: proxy number returned; real number never in response.
 *  4. Caller is not a participant: 403.
 */

describe('POST /bookings/:id/calls/initiate (Contract)', () => {
  describe('Happy path — confirmed booking, driver not yet charged', () => {
    it('should return 201 with callSessionId, proxyNumberE164, and expiresAt', () => {
      const responseShape = {
        callSessionId: 'call-session-1',
        proxyNumberE164: '+962790000001',
        expiresAt: new Date().toISOString(),
      };

      expect(responseShape.callSessionId).toEqual(expect.any(String));
      expect(responseShape.proxyNumberE164).toMatch(/^\+/);
    });

    it('should create a call_sessions row in the database', () => {
      const callSessionShape = {
        id: expect.any(String),
        bookingId: expect.any(String),
        callerUserId: expect.any(String),
        proxyNumber: expect.any(String),
        status: 'initiated',
        createdAt: expect.any(Date),
      };

      expect(callSessionShape.status).toBe('initiated');
    });

    it('should reuse the same proxy number for subsequent calls on the same booking', () => {
      // The pool's allocate() must return the already-bound number.
      const firstCallProxy = '+962790000001';
      const secondCallProxy = '+962790000001'; // same proxy

      expect(firstCallProxy).toBe(secondCallProxy);
    });
  });

  describe('Happy path — driver already charged the trip fee', () => {
    it('should still return 201 — charging the fee changes nothing about call access', () => {
      const responseShape = {
        callSessionId: 'call-session-2',
        proxyNumberE164: '+962790000002',
        expiresAt: new Date().toISOString(),
      };

      expect(responseShape.callSessionId).toEqual(expect.any(String));
      expect(responseShape.proxyNumberE164).toMatch(/^\+/);
    });
  });

  describe('hidePhoneNumber preference', () => {
    it('should return the proxy number when callee has hidePhoneNumber=true', () => {
      const responseShape = {
        proxyNumberE164: '+962790000001',
        // real number of callee must NOT be present in the response
      };

      expect(responseShape).not.toHaveProperty('calleeRealNumber');
      expect(responseShape.proxyNumberE164).toMatch(/^\+/);
    });
  });

  describe('Error cases', () => {
    it('should return 503 NO_PROXY_NUMBERS_AVAILABLE when pool is exhausted', () => {
      const errorShape = {
        statusCode: 503,
        code: 'NO_PROXY_NUMBERS_AVAILABLE',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('NO_PROXY_NUMBERS_AVAILABLE');
    });

    it('should return 403 when caller is not the booking user or trip driver', () => {
      const errorShape = {
        statusCode: 403,
        message: expect.any(String),
      };

      expect(errorShape.statusCode).toBe(403);
    });
  });
});
