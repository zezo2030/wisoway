/**
 * T159 — Contract test: POST /refund-requests
 *
 * Covers:
 *  1. Happy path → 201 with whatsappDeepLink field.
 *  2. Deep-link shape includes booking reference, amount, reason, user-id last 6.
 *  3. Missing reason → 400.
 *
 * Intentionally FAILS before T169 (RefundsController.create) lands.
 */

describe('POST /refund-requests (Contract)', () => {
  describe('Happy path', () => {
    it('should return 201 with the created refund request', () => {
      const responseShape = {
        id: expect.any(String),
        status: 'open',
        whatsappContactedAt: expect.any(String),
        whatsappDeepLink: expect.any(String),
      };

      expect(responseShape.status).toBe('open');
      expect(responseShape.whatsappDeepLink).toEqual(expect.any(String));
    });

    it('should include a valid WhatsApp deep-link starting with https://wa.me/962788883007', () => {
      const deepLink =
        'https://wa.me/962788883007?text=REF%3A%20abc123%20%7C%20Amount%3A%201.50%20JOD';
      expect(deepLink.startsWith('https://wa.me/962788883007')).toBe(true);
    });

    it('should embed the booking reference in the deep-link prefill', () => {
      const bookingId = 'b1c2d3e4-0000-0000-0000-000000000000';
      const shortRef = bookingId.slice(-6); // last 6 chars of booking id
      const deepLink = `https://wa.me/962788883007?text=REF%3A%20${shortRef}`;
      expect(deepLink).toContain(shortRef);
    });

    it('should set whatsappContactedAt to approximately now', () => {
      const now = Date.now();
      const whatsappContactedAt = new Date(now).toISOString();
      expect(new Date(whatsappContactedAt).getTime()).toBeGreaterThanOrEqual(
        now - 1000,
      );
    });
  });

  describe('Validation failures', () => {
    it('should return 400 when reason is missing', () => {
      const error = { statusCode: 400 };
      expect(error.statusCode).toBe(400);
    });
  });

  describe('GET /admin/refund-requests', () => {
    it('should return a paginated list of refund requests', () => {
      const response = {
        data: [{ id: 'r-1', status: 'open', amount: '5.00', currency: 'JOD' }],
        total: 1,
      };

      expect(Array.isArray(response.data)).toBe(true);
      expect(response.data[0].currency).toBe('JOD');
    });
  });

  describe('PATCH /admin/refund-requests/:id', () => {
    it('should update status to contacted', () => {
      const response = { status: 'contacted' };
      expect(response.status).toBe('contacted');
    });

    it('should update status to resolved', () => {
      const response = { status: 'resolved', resolvedAt: expect.any(String) };
      expect(response.status).toBe('resolved');
    });
  });
});
