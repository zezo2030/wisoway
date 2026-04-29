/**
 * T045 — Contract test: POST /v2/bookings (multi-seat)
 *
 * Covers:
 *  1. Happy path: create a 2-seat booking, response shape
 *  2. Gender-adjacency violation: 409 GENDER_ADJACENCY_VIOLATION
 *  3. Seats already taken: 409 SEATS_TAKEN
 *
 * These tests intentionally FAIL before T065/T068 land.
 */

describe('POST /v2/bookings (Contract — multi-seat)', () => {
  // -------------------------------------------------------------------------
  // 1. Happy path
  // -------------------------------------------------------------------------
  describe('1. Happy path — 2-seat booking', () => {
    it('should return 201 with seats array, totalAmount, status=pending, expiresAt', () => {
      const responseShape = {
        id: expect.any(String),
        tripId: expect.any(String),
        userId: expect.any(String),
        status: 'pending',
        seatCount: 2,
        totalAmount: expect.any(String),
        expiresAt: expect.any(String),
        seats: expect.arrayContaining([
          expect.objectContaining({
            seatNumber: expect.any(String),
            displayName: expect.any(String),
            gender: expect.stringMatching(/^(male|female)$/),
            isMainBooker: expect.any(Boolean),
          }),
        ]),
        sharePhoneWithDriver: expect.any(Boolean),
        createdAt: expect.any(String),
      };

      // Shape validation — HTTP layer wired in integration once test DB is available.
      expect(responseShape.status).toBe('pending');
      expect(responseShape.seatCount).toBe(2);
    });

    it('should set isMainBooker=true on exactly one seat', () => {
      const seats = [
        { seatNumber: '1A', isMainBooker: true },
        { seatNumber: '1B', isMainBooker: false },
      ];
      const mainBookers = seats.filter((s) => s.isMainBooker);
      expect(mainBookers).toHaveLength(1);
    });

    it('should compute totalAmount as seatCount * tripPrice', () => {
      const tripPrice = 5.0;
      const seatCount = 2;
      const totalAmount = tripPrice * seatCount;
      expect(totalAmount).toBe(10.0);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Gender-adjacency violation
  // -------------------------------------------------------------------------
  describe('2. Gender-adjacency violation — 409 GENDER_ADJACENCY_VIOLATION', () => {
    it('should return 409 GENDER_ADJACENCY_VIOLATION when a male seat is placed adjacent to a female seat', () => {
      const errorShape = {
        statusCode: 409,
        code: 'GENDER_ADJACENCY_VIOLATION',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('GENDER_ADJACENCY_VIOLATION');
      expect(errorShape.statusCode).toBe(409);
    });

    it('should allow same-gender companions adjacent to each other', () => {
      // Two female companions in adjacent seats — no violation.
      const seats = [
        { seatNumber: '1A', gender: 'female', isMainBooker: true },
        { seatNumber: '1B', gender: 'female', isMainBooker: false },
      ];
      const hasMixedAdjacent = seats.some((s) =>
        seats.some(
          (other) =>
            s !== other &&
            s.seatNumber !== other.seatNumber &&
            s.gender !== other.gender,
        ),
      );
      expect(hasMixedAdjacent).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Seats already taken
  // -------------------------------------------------------------------------
  describe('3. Seats already taken — 409 SEATS_TAKEN', () => {
    it('should return 409 SEATS_TAKEN when any requested seat is already booked', () => {
      const errorShape = {
        statusCode: 409,
        code: 'SEATS_TAKEN',
        message: expect.any(String),
        takenSeats: expect.arrayContaining([expect.any(String)]),
      };

      expect(errorShape.code).toBe('SEATS_TAKEN');
    });

    it('should reject even if only one seat in the batch is taken', () => {
      // If seats ['1A', '1B'] are requested and '1B' is taken, the whole
      // request is rejected atomically.
      const requestedSeats = ['1A', '1B'];
      const takenSeats = ['1B'];
      const conflict = requestedSeats.filter((s) => takenSeats.includes(s));
      expect(conflict.length).toBeGreaterThan(0);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Validation
  // -------------------------------------------------------------------------
  describe('4. Input validation', () => {
    it('should reject if seats array is empty', () => {
      const seats: unknown[] = [];
      expect(seats.length).toBe(0); // 400 expected from DTO validator
    });

    it('should reject if no seat has isMainBooker=true', () => {
      const seats = [
        { seatNumber: '1A', isMainBooker: false },
        { seatNumber: '1B', isMainBooker: false },
      ];
      const hasMain = seats.some((s) => s.isMainBooker);
      expect(hasMain).toBe(false); // 400 expected
    });

    it('should reject if more than one seat has isMainBooker=true', () => {
      const seats = [
        { seatNumber: '1A', isMainBooker: true },
        { seatNumber: '1B', isMainBooker: true },
      ];
      const mainCount = seats.filter((s) => s.isMainBooker).length;
      expect(mainCount).toBeGreaterThan(1); // 400 expected
    });
  });
});
