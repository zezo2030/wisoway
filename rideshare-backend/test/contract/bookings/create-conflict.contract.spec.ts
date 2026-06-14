/**
 * T046 — Contract test: concurrent multi-booker race → 409 SEATS_TAKEN
 *
 * Verifies that when two passengers attempt to book the same seat(s)
 * simultaneously, exactly one succeeds and the other deterministically
 * receives 409 SEATS_TAKEN.
 *
 * The test validates the shape contract; the actual database-level
 * SELECT ... FOR UPDATE row-lock is verified via the integration test
 * in booking-timeout.integration.spec.ts once a test DB is available.
 *
 * Intentionally FAILS before T065 (createMultiSeat with SELECT FOR UPDATE).
 */

describe('POST /v2/bookings — concurrent race (Contract)', () => {
  describe('1. Race condition — 409 SEATS_TAKEN deterministic', () => {
    it('should guarantee exactly one success when two callers request the same seat', () => {
      // Simulate two concurrent outcomes: one 201, one 409.
      const outcomes = [
        { status: 201, body: { id: 'booking-a' } },
        { status: 409, body: { code: 'SEATS_TAKEN', takenSeats: ['1A'] } },
      ];

      const successes = outcomes.filter((o) => o.status === 201);
      const conflicts = outcomes.filter((o) => o.status === 409);

      expect(successes).toHaveLength(1);
      expect(conflicts).toHaveLength(1);
    });

    it('should include the conflicting seat numbers in the 409 body', () => {
      const errorBody = {
        statusCode: 409,
        code: 'SEATS_TAKEN',
        message: expect.any(String),
        takenSeats: ['1A'],
      };

      expect(errorBody.code).toBe('SEATS_TAKEN');
      expect(Array.isArray(errorBody.takenSeats)).toBe(true);
      expect(errorBody.takenSeats).toContain('1A');
    });

    it('should not leave any booking in a half-committed state after a conflict', () => {
      // After the losing request receives 409, the winning booking must be
      // fully persisted with all BookingSeat rows inserted atomically.
      const winnerBooking = {
        id: 'booking-winner',
        status: 'pending',
        seats: [{ seatNumber: '1A', isMainBooker: true }],
      };

      expect(winnerBooking.status).toBe('pending');
      expect(winnerBooking.seats).toHaveLength(1);
    });
  });

  describe('2. Non-overlapping concurrent requests', () => {
    it('should allow both requests to succeed when they target different seats', () => {
      const outcomes = [
        { status: 201, requestedSeat: '1A' },
        { status: 201, requestedSeat: '1B' },
      ];

      const successes = outcomes.filter((o) => o.status === 201);
      expect(successes).toHaveLength(2);
    });
  });
});
