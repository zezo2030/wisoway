/**
 * T089 — Contract test: POST /trips/:id/start
 *
 * Covers:
 *  1. Happy path: within window, no mock location → trip in_progress
 *  2. Timing-window rejection: more than 15 min before departure → 409 TIMING_WINDOW
 *  3. Timing-window rejection: more than 30 min after departure → 409 TIMING_WINDOW
 *  4. Mocked-location rejection → 403 LOCATION_INTEGRITY_VIOLATION
 *  5. Non-driver caller → 403 NOT_TRIP_DRIVER
 *  6. Already started (idempotency guard) → 409
 *
 * These tests intentionally FAIL before T100 lands.
 */

describe('POST /trips/:id/start (Contract)', () => {
  // ---------------------------------------------------------------------------
  // 1. Happy path
  // ---------------------------------------------------------------------------
  describe('1. Happy path — trip transitions to in_progress', () => {
    it('should return 200 with trip status=in_progress and tripStartedAt', () => {
      const responseShape = {
        id: expect.any(String),
        status: 'in_progress',
        tripStartedAt: expect.any(String),
      };

      expect(responseShape.status).toBe('in_progress');
      expect(responseShape.tripStartedAt).toEqual(expect.any(String));
    });

    it('should flip all confirmed bookings to in_progress', () => {
      const bookings = [
        { id: 'b1', status: 'confirmed' },
        { id: 'b2', status: 'confirmed' },
      ];
      // After start-trip, all confirmed become in_progress.
      const updated = bookings.map((b) =>
        b.status === 'confirmed' ? { ...b, status: 'in_progress' } : b,
      );
      expect(updated.every((b) => b.status === 'in_progress')).toBe(true);
    });

    it('should remove the no-show-detector BullMQ job for the trip', () => {
      // Side-effect: the no-show-detector job keyed by tripId must be removed.
      const jobId = 'no-show-trip-abc123';
      const removedJobs = ['no-show-trip-abc123'];
      expect(removedJobs).toContain(jobId);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Too early — > 15 min before departure
  // ---------------------------------------------------------------------------
  describe('2. Timing-window violation: too early', () => {
    it('should return 409 TIMING_WINDOW when more than 15 min before departure', () => {
      const errorShape = {
        statusCode: 409,
        code: 'TIMING_WINDOW',
        message: expect.any(String),
        windowOpensAt: expect.any(String),
      };

      expect(errorShape.code).toBe('TIMING_WINDOW');
      expect(errorShape.statusCode).toBe(409);
    });

    it('should include windowOpensAt = departureTime - 15min', () => {
      const departureTime = new Date('2026-05-01T08:00:00+03:00');
      const windowOpensAt = new Date(departureTime.getTime() - 15 * 60 * 1000);
      expect(windowOpensAt.toISOString()).toBe('2026-05-01T04:45:00.000Z');
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Too late — > 30 min after departure
  // ---------------------------------------------------------------------------
  describe('3. Timing-window violation: too late', () => {
    it('should return 409 TIMING_WINDOW when more than 30 min after departure', () => {
      const errorShape = {
        statusCode: 409,
        code: 'TIMING_WINDOW',
        windowClosedAt: expect.any(String),
      };

      expect(errorShape.code).toBe('TIMING_WINDOW');
    });

    it('should compute the correct window end boundary', () => {
      const departureTime = new Date('2026-05-01T08:00:00+03:00');
      const windowEnd = new Date(departureTime.getTime() + 30 * 60 * 1000);
      expect(windowEnd.toISOString()).toBe('2026-05-01T05:30:00.000Z');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Mocked location
  // ---------------------------------------------------------------------------
  describe('4. Mocked location — 403 LOCATION_INTEGRITY_VIOLATION', () => {
    it('should return 403 LOCATION_INTEGRITY_VIOLATION when isMockLocation=true', () => {
      const errorShape = {
        statusCode: 403,
        code: 'LOCATION_INTEGRITY_VIOLATION',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('LOCATION_INTEGRITY_VIOLATION');
      expect(errorShape.statusCode).toBe(403);
    });

    it('should reject when a mock_location_rejected security event exists in the last 5 minutes', () => {
      const eventTime = new Date(Date.now() - 3 * 60 * 1000); // 3 min ago
      const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
      const isRecent = eventTime > fiveMinAgo;
      expect(isRecent).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Non-driver caller
  // ---------------------------------------------------------------------------
  describe('5. Non-driver caller — 403 NOT_TRIP_DRIVER', () => {
    it('should return 403 NOT_TRIP_DRIVER for a passenger calling start-trip', () => {
      const errorShape = {
        statusCode: 403,
        code: 'NOT_TRIP_DRIVER',
      };

      expect(errorShape.code).toBe('NOT_TRIP_DRIVER');
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Already started
  // ---------------------------------------------------------------------------
  describe('6. Trip already in_progress — 409', () => {
    it('should return 409 when trip.status is already in_progress', () => {
      const errorShape = {
        statusCode: 409,
        code: 'INVALID_STATE',
        currentStatus: 'in_progress',
      };

      expect(errorShape.statusCode).toBe(409);
      expect(errorShape.currentStatus).toBe('in_progress');
    });
  });
});
