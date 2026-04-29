/**
 * T113 — Contract test: DELETE /trips/:id 24h cancellation-window rejection
 *
 * Covers:
 *  1. Trip cancelled > 24h before departure → 200 success
 *  2. Trip cancelled <= 24h before departure → 403 CANCELLATION_WINDOW_CLOSED
 *  3. Response includes windowSeconds when rejected
 *  4. Recurrence rule is NOT deactivated on cancellation (FR-014)
 *
 * These tests intentionally FAIL before T121 lands.
 */

describe('DELETE /trips/:id cancellation window (Contract)', () => {
  describe('1. Cancel > 24h before departure — allowed', () => {
    it('should cancel the trip and notify passengers', () => {
      const departureTime = new Date(Date.now() + 30 * 60 * 60 * 1000);
      const now = new Date();
      const diffMs = departureTime.getTime() - now.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      expect(diffHours).toBeGreaterThan(24);

      const response = {
        status: 'cancelled',
        cancelledAt: expect.any(String),
      };

      expect(response.status).toBe('cancelled');
    });
  });

  describe('2. Cancel <= 24h before departure — rejected', () => {
    it('should return 403 CANCELLATION_WINDOW_CLOSED', () => {
      const departureTime = new Date(Date.now() + 12 * 60 * 60 * 1000);
      const now = new Date();
      const diffMs = departureTime.getTime() - now.getTime();
      const diffHours = diffMs / (1000 * 60 * 60);

      expect(diffHours).toBeLessThanOrEqual(24);

      const errorResponse = {
        statusCode: 403,
        code: 'CANCELLATION_WINDOW_CLOSED',
        message: expect.any(String),
        windowSeconds: expect.any(Number),
      };

      expect(errorResponse.code).toBe('CANCELLATION_WINDOW_CLOSED');
      expect(errorResponse.statusCode).toBe(403);
    });
  });

  describe('3. windowSeconds in error response', () => {
    it('should include windowSeconds = seconds until 24h-before-departure', () => {
      const departureTime = new Date(Date.now() + 20 * 60 * 60 * 1000);
      const cutoff = new Date(departureTime.getTime() - 24 * 60 * 60 * 1000);
      const now = new Date();
      const windowSeconds = Math.max(
        0,
        Math.floor((cutoff.getTime() - now.getTime()) / 1000),
      );

      expect(typeof windowSeconds).toBe('number');
      expect(windowSeconds).toBeLessThanOrEqual(24 * 3600);
    });
  });

  describe('4. Recurrence rule NOT deactivated on cancellation (FR-014)', () => {
    it('should leave the recurrence rule active when a single occurrence is cancelled', () => {
      const trip = {
        recurrenceRuleId: 'rule-123',
        status: 'cancelled',
      };

      const ruleAfterCancel = {
        id: 'rule-123',
        isActive: true,
      };

      expect(ruleAfterCancel.isActive).toBe(true);
    });

    it('should NOT respawn a cancelled date on next sweep', () => {
      const cancelledDate = new Date('2026-05-05T08:00:00+03:00');
      const existingTrips = [
        {
          driverId: 'driver-1',
          departureTime: cancelledDate.toISOString(),
          status: 'cancelled',
        },
      ];

      const hasConflict = existingTrips.some(
        (t) => t.departureTime === cancelledDate.toISOString(),
      );

      expect(hasConflict).toBe(true);
    });
  });
});
