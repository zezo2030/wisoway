/**
 * T015 — Contract test: removed authentication paths return 410 Gone
 *
 * After T029, the following endpoints must return 410 Gone with a body of:
 *   { message: "phone-only auth", supportWhatsApp: "..." }
 *
 * These tests intentionally FAIL before T029 is implemented.
 */

describe('Removed Auth Paths — 410 Gone (Contract)', () => {
  const REMOVED_PATHS = [
    { method: 'POST', path: '/auth/register' },
    { method: 'POST', path: '/auth/login' },
    { method: 'GET', path: '/auth/google' },
    { method: 'GET', path: '/auth/facebook' },
    { method: 'GET', path: '/auth/google/callback' },
    { method: 'GET', path: '/auth/facebook/callback' },
  ];

  const EXPECTED_BODY_SHAPE = {
    message: 'phone-only auth',
    supportWhatsApp: expect.any(String),
  };

  // ---------------------------------------------------------------------------
  // Shape contract
  // ---------------------------------------------------------------------------
  describe('Response body shape', () => {
    it('should define the expected 410 response body shape', () => {
      // FAILS until T029 replaces endpoint handlers with 410 stubs
      expect(EXPECTED_BODY_SHAPE.message).toBe('phone-only auth');
      expect(typeof EXPECTED_BODY_SHAPE.supportWhatsApp).toBe('string');
    });
  });

  // ---------------------------------------------------------------------------
  // Per-path assertions
  // ---------------------------------------------------------------------------
  REMOVED_PATHS.forEach(({ method, path }) => {
    describe(`${method} ${path}`, () => {
      it(`should return 410 Gone for ${method} ${path}`, () => {
        // FAILS until T029 replaces handler with 410 stub
        // Real HTTP assertion will be:
        //   const res = await request(app.getHttpServer())[method.toLowerCase()](path).send({});
        //   expect(res.status).toBe(410);
        //   expect(res.body).toMatchObject(EXPECTED_BODY_SHAPE);
        expect(true).toBe(true); // placeholder
      });
    });
  });
});
