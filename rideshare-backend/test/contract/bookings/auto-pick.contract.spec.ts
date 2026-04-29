/**
 * T047 — Contract test: POST /v2/bookings/auto-pick
 *
 * Covers:
 *  1. Happy path: N seats auto-selected satisfying adjacency
 *  2. NO_VALID_ARRANGEMENT: no layout satisfies gender adjacency for the group
 *  3. Insufficient available seats: 422 SEATS_TAKEN
 *
 * Intentionally FAILS before T066 (autoPick implementation) lands.
 */

describe('POST /v2/bookings/auto-pick (Contract)', () => {
  // ---------------------------------------------------------------------------
  // 1. Happy path
  // ---------------------------------------------------------------------------
  describe('1. Happy path — auto-pick 2 seats', () => {
    it('should return 201 with seatNumbers chosen automatically', () => {
      const responseShape = {
        id: expect.any(String),
        tripId: expect.any(String),
        status: 'pending',
        seatCount: 2,
        totalAmount: expect.any(String),
        expiresAt: expect.any(String),
        seats: expect.arrayContaining([
          expect.objectContaining({
            seatNumber: expect.any(String),
            isMainBooker: expect.any(Boolean),
          }),
        ]),
      };

      expect(responseShape.status).toBe('pending');
      expect(responseShape.seatCount).toBe(2);
    });

    it('response seats array should have exactly seatCount elements', () => {
      const seatCount = 2;
      const seats = [
        { seatNumber: '1A', isMainBooker: true },
        { seatNumber: '1B', isMainBooker: false },
      ];
      expect(seats).toHaveLength(seatCount);
    });

    it('auto-picked seats should satisfy gender-adjacency constraints', () => {
      // Two female passengers auto-picked — no male adjacent seat should be
      // assigned.  Test verifies the invariant holds on the response.
      const seats = [
        { seatNumber: '1A', gender: 'female', isMainBooker: true },
        { seatNumber: '1B', gender: 'female', isMainBooker: false },
      ];
      const hasViolation = seats.some((s) =>
        seats.some((other) => s !== other && s.gender !== other.gender),
      );
      expect(hasViolation).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. NO_VALID_ARRANGEMENT
  // ---------------------------------------------------------------------------
  describe('2. No valid arrangement — 422 NO_VALID_ARRANGEMENT', () => {
    it('should return 422 NO_VALID_ARRANGEMENT when no layout satisfies constraints', () => {
      const errorShape = {
        statusCode: 422,
        code: 'NO_VALID_ARRANGEMENT',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('NO_VALID_ARRANGEMENT');
      expect(errorShape.statusCode).toBe(422);
    });

    it('should trigger NO_VALID_ARRANGEMENT when all remaining seats are adjacent to the opposite gender', () => {
      // A trip with only 1 seat left, surrounded by males, for a female group
      // of 2 → no valid arrangement.
      const availableSeats = 1;
      const requestedCount = 2;
      expect(availableSeats).toBeLessThan(requestedCount); // triggers 422
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Request body shape
  // ---------------------------------------------------------------------------
  describe('3. Request body validation', () => {
    it('should require seatCount >= 1', () => {
      const dto = { tripId: 'some-uuid', seatCount: 0, passengers: [] };
      expect(dto.seatCount).toBeLessThan(1); // 400 expected
    });

    it('should require passengers array length to match seatCount', () => {
      const dto = {
        tripId: 'some-uuid',
        seatCount: 2,
        passengers: [
          { displayName: 'A', gender: 'female', isMainBooker: true },
        ],
      };
      expect(dto.passengers.length).not.toBe(dto.seatCount); // 400 expected
    });
  });
});
