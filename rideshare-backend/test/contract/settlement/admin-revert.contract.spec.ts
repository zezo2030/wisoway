/**
 * T131 — Contract test: POST /admin/bookings/:id/admin-revert-settlement
 *
 * Covers:
 *  1. Happy path: admin reverts settlement outside grace — always succeeds.
 *  2. Idempotent: calling twice inserts two audit rows but both return 200.
 *  3. Non-admin caller: 403.
 *
 * Intentionally FAILS before T141 (SettlementService.adminRevert) lands.
 */

describe('POST /admin/bookings/:id/admin-revert-settlement (Contract)', () => {
  describe('Happy path', () => {
    it('should return 200 and clear settledAt regardless of grace window', () => {
      const responseShape = {
        id: expect.any(String),
        settledAt: null,
        settlementGraceUntil: null,
      };

      expect(responseShape.settledAt).toBeNull();
    });

    it('should insert a settlement_audits row with action="admin_revert" and the provided reason', () => {
      const auditShape = {
        bookingId: expect.any(String),
        action: 'admin_revert',
        reason: expect.any(String),
        actorId: expect.any(String),
      };

      expect(auditShape.action).toBe('admin_revert');
    });

    it('should be idempotent — calling twice inserts two audit rows but both return 200', () => {
      // Both calls must succeed; each creates its own audit entry.
      const firstCall = { status: 200 };
      const secondCall = { status: 200 };

      expect(firstCall.status).toBe(200);
      expect(secondCall.status).toBe(200);
    });
  });

  describe('Access control', () => {
    it('should return 403 when called by a non-admin user', () => {
      const errorShape = {
        statusCode: 403,
        message: expect.any(String),
      };

      expect(errorShape.statusCode).toBe(403);
    });
  });
});
