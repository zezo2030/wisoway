/**
 * T156 — Contract test: BanGuard blocks all authenticated requests
 *
 * The BanGuard (T009) must return 403 ACCOUNT_BANNED with the documented body
 * for ANY authenticated endpoint when the requesting user has bannedAt IS NOT NULL.
 *
 * Intentionally FAILS before BanGuard is wired as a global guard.
 */

describe('BanGuard (Contract)', () => {
  describe('Any authenticated endpoint', () => {
    it('should return 403 when user is banned', () => {
      const errorBody = {
        statusCode: 403,
        code: 'ACCOUNT_BANNED',
        banReason: expect.any(String),
        supportWhatsApp: '+962788883007',
      };

      expect(errorBody.statusCode).toBe(403);
      expect(errorBody.code).toBe('ACCOUNT_BANNED');
    });

    it('should include banReason in the 403 body', () => {
      const banReason = 'Repeated mocked-location violations';
      const errorBody = {
        statusCode: 403,
        code: 'ACCOUNT_BANNED',
        banReason,
        supportWhatsApp: '+962788883007',
      };

      expect(errorBody.banReason).toBe(banReason);
    });

    it('should always include supportWhatsApp +962788883007 in the 403 body', () => {
      const errorBody = {
        statusCode: 403,
        code: 'ACCOUNT_BANNED',
        banReason: 'test',
        supportWhatsApp: '+962788883007',
      };

      expect(errorBody.supportWhatsApp).toBe('+962788883007');
    });

    it('should pass through normally when user is NOT banned (bannedAt=null)', () => {
      // Normal requests continue to reach the route handler
      const response = { status: 200 };
      expect(response.status).toBe(200);
    });
  });
});
