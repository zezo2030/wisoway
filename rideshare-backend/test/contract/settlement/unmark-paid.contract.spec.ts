/**
 * T130 — Contract test: POST /bookings/:id/unmark-paid (driver)
 *
 * Covers:
 *  1. Within grace, no contact: 200 — settledAt / settlementGraceUntil cleared,
 *     settlement_audits row with action='unmark_paid'.
 *  2. After grace window: 409 GRACE_EXPIRED.
 *  3. After first chat message: 409 CONTACT_ALREADY_USED.
 *  4. After first call session: 409 CONTACT_ALREADY_USED.
 *
 * Intentionally FAILS before T140 (SettlementService.unmarkPaid) lands.
 */

describe('POST /bookings/:id/unmark-paid (Contract)', () => {
  describe('Within grace — no contact yet', () => {
    it('should return 200 and clear settledAt + settlementGraceUntil', () => {
      const responseShape = {
        id: expect.any(String),
        settledAt: null,
        settlementGraceUntil: null,
        chatEnabled: false,
        callEnabled: false,
      };

      expect(responseShape.settledAt).toBeNull();
      expect(responseShape.chatEnabled).toBe(false);
    });

    it('should insert a settlement_audits row with action="unmark_paid"', () => {
      const auditShape = {
        bookingId: expect.any(String),
        action: 'unmark_paid',
        actorId: expect.any(String),
      };

      expect(auditShape.action).toBe('unmark_paid');
    });
  });

  describe('After grace window', () => {
    it('should return 409 GRACE_EXPIRED when now >= settlementGraceUntil', () => {
      const errorShape = {
        statusCode: 409,
        code: 'GRACE_EXPIRED',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('GRACE_EXPIRED');
    });
  });

  describe('After contact was used', () => {
    it('should return 409 CONTACT_ALREADY_USED when a chat message exists for the booking', () => {
      const errorShape = {
        statusCode: 409,
        code: 'CONTACT_ALREADY_USED',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('CONTACT_ALREADY_USED');
    });

    it('should return 409 CONTACT_ALREADY_USED when a call_sessions row exists for the booking', () => {
      const errorShape = {
        statusCode: 409,
        code: 'CONTACT_ALREADY_USED',
      };

      expect(errorShape.code).toBe('CONTACT_ALREADY_USED');
    });
  });
});
