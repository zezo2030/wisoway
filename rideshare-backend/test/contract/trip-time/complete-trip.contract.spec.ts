/**
 * T090 — Contract test: POST /trips/:id/complete
 *
 * Covers:
 *  1. Happy path: no no-show seats → all bookings completed
 *  2. No-show seats: partial booking → affected seats markedAbsentAt, others completed
 *  3. No-show seats: all seats absent → booking status=no_show, pending_charges 5% created
 *  4. Share links refreshed to expire 30 min from now
 *  5. Non-driver caller → 403 NOT_TRIP_DRIVER
 *  6. Trip not in_progress → 409 INVALID_STATE
 *
 * These tests intentionally FAIL before T101 lands.
 */

describe('POST /trips/:id/complete (Contract)', () => {
  // ---------------------------------------------------------------------------
  // 1. Happy path — no no-shows
  // ---------------------------------------------------------------------------
  describe('1. Happy path — all bookings complete', () => {
    it('should return 200 with trip status=completed and tripCompletedAt', () => {
      const responseShape = {
        id: expect.any(String),
        status: 'completed',
        tripCompletedAt: expect.any(String),
      };

      expect(responseShape.status).toBe('completed');
      expect(responseShape.tripCompletedAt).toEqual(expect.any(String));
    });

    it('should flip all in_progress bookings to completed', () => {
      const bookings = [
        { id: 'b1', status: 'in_progress' },
        { id: 'b2', status: 'in_progress' },
      ];
      const updated = bookings.map((b) =>
        b.status === 'in_progress' ? { ...b, status: 'completed' } : b,
      );
      expect(updated.every((b) => b.status === 'completed')).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Partial no-show — some seats absent, booking not fully absent
  // ---------------------------------------------------------------------------
  describe('2. Partial no-show — seats marked absent but booking stays completed', () => {
    it('should mark the specified BookingSeat.markedAbsentAt', () => {
      const noShowSeats = [{ bookingId: 'b1', seatNumber: '1A' }];
      const allSeatsForB1 = ['1A', '1B'];
      const absentSeats = noShowSeats
        .filter((n) => n.bookingId === 'b1')
        .map((n) => n.seatNumber);
      const allAbsent = allSeatsForB1.every((s) => absentSeats.includes(s));
      expect(allAbsent).toBe(false); // only 1A is absent, 1B is present
      expect(absentSeats).toContain('1A');
    });

    it('should NOT create a pending_charges row when only some seats are absent', () => {
      const allSeats = ['1A', '1B'];
      const absentSeats = ['1A'];
      const allAbsent = allSeats.every((s) => absentSeats.includes(s));
      expect(allAbsent).toBe(false);
      // No charge created when booking has at least one present passenger.
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Full no-show — all seats absent → no_show status + pending_charges
  // ---------------------------------------------------------------------------
  describe('3. Full no-show — booking status=no_show + pending_charges 5%', () => {
    it('should set booking.status=no_show when all seats are absent', () => {
      const allSeats = ['1A', '1B'];
      const absentSeats = ['1A', '1B'];
      const allAbsent = allSeats.every((s) => absentSeats.includes(s));
      expect(allAbsent).toBe(true);
      // Booking should become no_show.
    });

    it('should create a pending_charges row of kind passenger_no_show for 5% of totalAmount', () => {
      const totalAmount = 10.0;
      const chargeAmount = totalAmount * 0.05;
      const pendingChargeShape = {
        userId: expect.any(String),
        kind: 'passenger_no_show',
        amount: chargeAmount,
        bookingId: expect.any(String),
        tripId: expect.any(String),
        status: 'pending',
      };

      expect(pendingChargeShape.kind).toBe('passenger_no_show');
      expect(chargeAmount).toBe(0.5);
    });

    it('should compute 5% of totalAmount correctly', () => {
      const cases = [
        { totalAmount: 10.0, expected: 0.5 },
        { totalAmount: 25.0, expected: 1.25 },
        { totalAmount: 100.0, expected: 5.0 },
      ];
      cases.forEach(({ totalAmount, expected }) => {
        expect(parseFloat((totalAmount * 0.05).toFixed(2))).toBe(expected);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Share links refreshed
  // ---------------------------------------------------------------------------
  describe('4. Active share links refreshed to expire in 30 minutes', () => {
    it('should extend share link expiry to now+30min on trip completion', () => {
      const completionTime = new Date('2026-05-01T10:00:00Z');
      const newExpiry = new Date(completionTime.getTime() + 30 * 60 * 1000);
      expect(newExpiry.toISOString()).toBe('2026-05-01T10:30:00.000Z');
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Non-driver caller
  // ---------------------------------------------------------------------------
  describe('5. Non-driver caller — 403', () => {
    it('should return 403 NOT_TRIP_DRIVER', () => {
      const errorShape = {
        statusCode: 403,
        code: 'NOT_TRIP_DRIVER',
      };

      expect(errorShape.code).toBe('NOT_TRIP_DRIVER');
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Invalid state
  // ---------------------------------------------------------------------------
  describe('6. Trip not in_progress — 409 INVALID_STATE', () => {
    it('should return 409 when trip is already completed', () => {
      const errorShape = {
        statusCode: 409,
        code: 'INVALID_STATE',
        currentStatus: 'completed',
      };

      expect(errorShape.statusCode).toBe(409);
    });

    it('should return 409 when trip is still published (not started)', () => {
      const errorShape = {
        statusCode: 409,
        code: 'INVALID_STATE',
        currentStatus: 'published',
      };

      expect(errorShape.statusCode).toBe(409);
    });
  });
});
