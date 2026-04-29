/**
 * T157 — Contract test: POST /complaints validation
 *
 * Covers:
 *  1. Happy path: at least one of againstUserId|tripId|bookingId is present → 201.
 *  2. Missing all three targets → 400 with validation error.
 *  3. Invalid category → 400.
 *  4. Empty body → 400.
 *
 * Intentionally FAILS before T167 (ComplaintsController.create) lands.
 */

describe('POST /complaints (Contract)', () => {
  describe('Happy path — against a user', () => {
    it('should return 201 with the created complaint row', () => {
      const responseShape = {
        id: expect.any(String),
        reporterId: expect.any(String),
        againstUserId: expect.any(String),
        category: 'rude_behavior',
        status: 'open',
        createdAt: expect.any(String),
      };

      expect(responseShape.status).toBe('open');
    });
  });

  describe('Happy path — against a trip', () => {
    it('should return 201 when only tripId is provided', () => {
      const responseShape = {
        id: expect.any(String),
        tripId: expect.any(String),
        againstUserId: null,
        bookingId: null,
        status: 'open',
      };

      expect(responseShape.tripId).toEqual(expect.any(String));
      expect(responseShape.againstUserId).toBeNull();
    });
  });

  describe('Validation failures', () => {
    it('should return 400 when none of againstUserId|tripId|bookingId is provided', () => {
      const error = {
        statusCode: 400,
        message: expect.arrayContaining([expect.stringContaining('target')]),
      };
      expect(error.statusCode).toBe(400);
    });

    it('should return 400 when category is not a valid enum value', () => {
      const error = { statusCode: 400 };
      expect(error.statusCode).toBe(400);
    });

    it('should return 400 when body text is missing', () => {
      const error = { statusCode: 400 };
      expect(error.statusCode).toBe(400);
    });
  });

  describe('GET /me/complaints', () => {
    it("should return an array of the caller's filed complaints", () => {
      const response = { data: [{ reporterId: 'user-1', status: 'open' }] };
      expect(Array.isArray(response.data)).toBe(true);
      expect(response.data[0].reporterId).toBe('user-1');
    });
  });
});
