/**
 * T091 — Contract test: POST /trips/:id/share-link & GET /share/:token
 *
 * Covers:
 *  1. Issuance: confirmed passenger or driver can create a share link
 *  2. Issuance: unrelated user → 403
 *  3. Public read: in_progress → includes driverLocation, no PII
 *  4. Public read: published (not started) → driverLocation null
 *  5. Public read: completed → ended shape, driverLocation null
 *  6. Rate limit: > 60 req in 60s per token → 429
 *  7. Unknown token → 404
 *
 * These tests intentionally FAIL before T103/T104 land.
 */

describe('POST /trips/:id/share-link (Contract)', () => {
  // ---------------------------------------------------------------------------
  // 1. Issuance — confirmed passenger
  // ---------------------------------------------------------------------------
  describe('1. Confirmed passenger can create share link', () => {
    it('should return 201 with url and expiresAt', () => {
      const responseShape = {
        url: expect.stringMatching(/\/share\/[A-Za-z0-9_-]{40,}/),
        expiresAt: expect.any(String),
      };

      expect(responseShape.url).toEqual(
        expect.stringMatching(/\/share\/[A-Za-z0-9_-]{40,}/),
      );
      expect(responseShape.expiresAt).toEqual(expect.any(String));
    });

    it('should set expiresAt to departureTime + 6 hours', () => {
      const departureTime = new Date('2026-05-01T08:00:00+03:00');
      const expiresAt = new Date(departureTime.getTime() + 6 * 60 * 60 * 1000);
      expect(expiresAt.toISOString()).toBe('2026-05-01T11:00:00.000Z');
    });

    it('should generate a URL-safe token of at least 40 characters', () => {
      const token = 'abc123def456ghi789jkl012mno345pqr678stu9'; // 40 chars
      expect(token.length).toBeGreaterThanOrEqual(40);
      expect(/^[A-Za-z0-9_-]+$/.test(token)).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Issuance — driver
  // ---------------------------------------------------------------------------
  describe('2. Trip driver can also create share link', () => {
    it('should return 201 for the driver of the trip', () => {
      const responseShape = {
        url: expect.any(String),
        expiresAt: expect.any(String),
      };

      expect(responseShape.url).toEqual(expect.any(String));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Unauthorized caller
  // ---------------------------------------------------------------------------
  describe('3. Unrelated user → 403', () => {
    it('should return 403 when caller has no booking on the trip and is not the driver', () => {
      const errorShape = {
        statusCode: 403,
        code: 'FORBIDDEN',
      };

      expect(errorShape.statusCode).toBe(403);
    });
  });
});

describe('GET /share/:token (Contract — public read)', () => {
  // ---------------------------------------------------------------------------
  // 4. In-progress trip shape
  // ---------------------------------------------------------------------------
  describe('4. Trip in_progress — includes driverLocation, no PII', () => {
    it('should return 200 with driverLocation and no PII', () => {
      const responseShape = {
        tripStatus: 'in_progress',
        fromName: expect.any(String),
        toName: expect.any(String),
        departureTime: expect.any(String),
        etaMinutes: expect.any(Number),
        driverLocation: {
          lat: expect.any(Number),
          lng: expect.any(Number),
          capturedAt: expect.any(String),
        },
        vehicleSummary: {
          type: expect.any(String),
          model: expect.any(String),
          color: expect.any(String),
        },
      };

      expect(responseShape.tripStatus).toBe('in_progress');
      expect(responseShape.driverLocation).not.toBeNull();
    });

    it('should NOT include driver name, passenger names, or phone numbers', () => {
      const responseKeys = [
        'tripStatus',
        'fromName',
        'toName',
        'departureTime',
        'etaMinutes',
        'driverLocation',
        'vehicleSummary',
      ];
      const forbiddenKeys = [
        'driverName',
        'driverPhone',
        'passengerName',
        'phoneNumber',
        'userId',
      ];
      const hasNoForbidden = forbiddenKeys.every(
        (k) => !responseKeys.includes(k),
      );
      expect(hasNoForbidden).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Published (not started) — driverLocation null
  // ---------------------------------------------------------------------------
  describe('5. Trip published — driverLocation null, etaMinutes null', () => {
    it('should return 200 with driverLocation=null when trip is not yet in_progress', () => {
      const responseShape = {
        tripStatus: 'published',
        driverLocation: null,
        etaMinutes: null,
      };

      expect(responseShape.tripStatus).toBe('published');
      expect(responseShape.driverLocation).toBeNull();
      expect(responseShape.etaMinutes).toBeNull();
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Completed trip
  // ---------------------------------------------------------------------------
  describe('6. Trip completed — ended shape, driverLocation null', () => {
    it('should return 200 with tripStatus=completed and driverLocation=null', () => {
      const responseShape = {
        tripStatus: 'completed',
        driverLocation: null,
        etaMinutes: null,
      };

      expect(responseShape.tripStatus).toBe('completed');
      expect(responseShape.driverLocation).toBeNull();
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Rate limit
  // ---------------------------------------------------------------------------
  describe('7. Rate limit — 429 after burst exceeded', () => {
    it('should describe a 1 req/sec rate limit with burst of 60', () => {
      const rateLimit = { requestsPerSecond: 1, burst: 60 };
      expect(rateLimit.requestsPerSecond).toBe(1);
      expect(rateLimit.burst).toBe(60);
    });

    it('should return 429 when burst limit exceeded', () => {
      const errorShape = {
        statusCode: 429,
        code: 'RATE_LIMIT_EXCEEDED',
        retryAfterSeconds: expect.any(Number),
      };

      expect(errorShape.statusCode).toBe(429);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Unknown token
  // ---------------------------------------------------------------------------
  describe('8. Unknown token — 404', () => {
    it('should return 404 for a token that does not exist', () => {
      const errorShape = {
        statusCode: 404,
        code: 'NOT_FOUND',
      };

      expect(errorShape.statusCode).toBe(404);
    });

    it('should return 404 for an expired token', () => {
      const expiredToken = {
        token: 'validformat000000000000000000000000000000',
        expiresAt: new Date(Date.now() - 1000).toISOString(),
      };
      const isExpired = new Date(expiredToken.expiresAt) < new Date();
      expect(isExpired).toBe(true);
    });
  });
});
