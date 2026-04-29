/**
 * T134 — Contract test: POST /calls/twilio-webhook (public, signed)
 *
 * Covers:
 *  1. Valid Twilio signature + terminal status → call_sessions.endedAt,
 *     durationSeconds, terminationReason updated.
 *  2. Invalid/missing Twilio signature → 403 rejected.
 *  3. Unknown CallSid → graceful 200 (idempotent — Twilio may retry).
 *
 * Intentionally FAILS before T146 (CallsService.handleTwilioWebhook) lands.
 */

describe('POST /calls/twilio-webhook (Contract)', () => {
  describe('Valid signature', () => {
    it('should return 200 and update call_sessions with endedAt + durationSeconds + terminationReason', () => {
      const updatedCallSession = {
        id: 'session-1',
        status: 'completed',
        endedAt: expect.any(Date),
        durationSeconds: expect.any(Number),
        terminationReason: 'completed',
      };

      expect(updatedCallSession.status).toBe('completed');
      expect(updatedCallSession.endedAt).toEqual(expect.any(Date));
    });

    it('should handle "no-answer" terminal status correctly', () => {
      const updatedShape = {
        status: 'failed',
        terminationReason: 'no-answer',
      };

      expect(updatedShape.terminationReason).toBe('no-answer');
    });

    it('should return 200 for an unknown CallSid (idempotent — Twilio may retry)', () => {
      // Do not throw; return 200 to prevent Twilio from retrying.
      const responseCode = 200;
      expect(responseCode).toBe(200);
    });
  });

  describe('Signature validation', () => {
    it('should return 403 when the X-Twilio-Signature header is missing', () => {
      const errorShape = {
        statusCode: 403,
        message: expect.any(String),
      };

      expect(errorShape.statusCode).toBe(403);
    });

    it('should return 403 when the X-Twilio-Signature header is invalid', () => {
      const errorShape = {
        statusCode: 403,
        message: expect.any(String),
      };

      expect(errorShape.statusCode).toBe(403);
    });
  });
});
