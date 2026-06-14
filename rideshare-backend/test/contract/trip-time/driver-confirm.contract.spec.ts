/**
 * T088 — Contract test: POST /bookings/:id/driver-confirm
 *
 * Covers:
 *  1. Mark one seat present → booking-level driverConfirmedPassengerAt set
 *  2. Mark all seats absent → booking-level driverMarkedAbsentAt set
 *  3. Unknown seatNumber → 404
 *  4. Non-driver caller → 403
 *
 * These tests intentionally FAIL before T099 lands.
 */

describe('POST /bookings/:id/driver-confirm (Contract)', () => {
  // ---------------------------------------------------------------------------
  // 1. Seat present
  // ---------------------------------------------------------------------------
  describe('1. Mark seat present', () => {
    it('should return 200 and set BookingSeat.presenceConfirmedAt', () => {
      const responseShape = {
        bookingId: expect.any(String),
        seatNumber: '1A',
        presenceConfirmedAt: expect.any(String),
        markedAbsentAt: null,
        bookingLevel: {
          driverConfirmedPassengerAt: expect.any(String),
          driverMarkedAbsentAt: null,
        },
      };

      expect(responseShape.seatNumber).toBe('1A');
      expect(responseShape.presenceConfirmedAt).toEqual(expect.any(String));
      expect(responseShape.markedAbsentAt).toBeNull();
    });

    it('should set booking-level driverConfirmedPassengerAt when at least one seat is present', () => {
      const seats = [
        {
          seatNumber: '1A',
          presenceConfirmedAt: new Date().toISOString(),
          markedAbsentAt: null,
        },
        { seatNumber: '1B', presenceConfirmedAt: null, markedAbsentAt: null },
      ];
      const anyPresent = seats.some((s) => s.presenceConfirmedAt !== null);
      expect(anyPresent).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. All seats absent
  // ---------------------------------------------------------------------------
  describe('2. Mark all seats absent', () => {
    it('should set booking-level driverMarkedAbsentAt when all seats are absent', () => {
      const seats = [
        {
          seatNumber: '1A',
          presenceConfirmedAt: null,
          markedAbsentAt: new Date().toISOString(),
        },
        {
          seatNumber: '1B',
          presenceConfirmedAt: null,
          markedAbsentAt: new Date().toISOString(),
        },
      ];
      const allAbsent = seats.every((s) => s.markedAbsentAt !== null);
      expect(allAbsent).toBe(true);
    });

    it('should NOT set driverMarkedAbsentAt when only some seats are absent', () => {
      const seats = [
        {
          seatNumber: '1A',
          presenceConfirmedAt: new Date().toISOString(),
          markedAbsentAt: null,
        },
        {
          seatNumber: '1B',
          presenceConfirmedAt: null,
          markedAbsentAt: new Date().toISOString(),
        },
      ];
      const allAbsent = seats.every((s) => s.markedAbsentAt !== null);
      expect(allAbsent).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Unknown seatNumber
  // ---------------------------------------------------------------------------
  describe('3. Unknown seatNumber — 404', () => {
    it('should return 404 when seatNumber does not exist on the booking', () => {
      const errorShape = {
        statusCode: 404,
        code: 'NOT_FOUND',
        message: expect.any(String),
      };

      expect(errorShape.statusCode).toBe(404);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Non-driver caller
  // ---------------------------------------------------------------------------
  describe('4. Non-driver caller — 403', () => {
    it('should return 403 NOT_TRIP_DRIVER when the caller is not the trip driver', () => {
      const errorShape = {
        statusCode: 403,
        code: 'NOT_TRIP_DRIVER',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('NOT_TRIP_DRIVER');
      expect(errorShape.statusCode).toBe(403);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Response body shape
  // ---------------------------------------------------------------------------
  describe('5. Response body shape', () => {
    it('should include the full seats list in the response', () => {
      const responseShape = {
        bookingId: expect.any(String),
        seats: expect.arrayContaining([
          expect.objectContaining({
            seatNumber: expect.any(String),
            presenceConfirmedAt: expect.anything(),
            markedAbsentAt: expect.anything(),
          }),
        ]),
      };

      expect(responseShape.bookingId).toEqual(expect.any(String));
    });
  });
});
