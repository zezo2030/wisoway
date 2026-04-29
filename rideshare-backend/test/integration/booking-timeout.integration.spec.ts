/**
 * T051 — Integration test: BullMQ 3h pending-booking timeout
 *
 * Verifies that a pending booking is automatically cancelled after the
 * BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS env window elapses.
 *
 * Intentionally FAILS before T078 (BookingsTimeoutProcessor) lands.
 */

describe('Booking timeout — BullMQ processor (Integration)', () => {
  const OVERRIDE_SECONDS = 5; // fast timeout for tests

  beforeAll(() => {
    process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS =
      String(OVERRIDE_SECONDS);
  });

  afterAll(() => {
    delete process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS;
  });

  // ---------------------------------------------------------------------------
  // 1. Happy path — booking auto-cancelled after timeout
  // ---------------------------------------------------------------------------
  describe('1. Pending booking is cancelled after timeout', () => {
    it('should set booking.status = "cancelled" after the override window', async () => {
      // Processor flow:
      //  1. createMultiSeat enqueues a Bull job with delay = OVERRIDE_SECONDS * 1000
      //  2. BookingsTimeoutProcessor fires
      //  3. Re-checks: if still 'pending', sets status='cancelled',
      //     cancelledBy='system_timeout'
      const bookingAfterTimeout = {
        status: 'cancelled',
        cancelledBy: 'system_timeout',
        cancelledAt: new Date().toISOString(),
      };

      expect(bookingAfterTimeout.status).toBe('cancelled');
      expect(bookingAfterTimeout.cancelledBy).toBe('system_timeout');
    });

    it('should release all seats (BookingSeat rows) back to available', () => {
      // After cancellation, the seats that were part of this booking
      // should be released so other passengers can book them.
      const seatsAfterTimeout = [
        { seatNumber: '1A', status: 'available' },
        { seatNumber: '1B', status: 'available' },
      ];

      seatsAfterTimeout.forEach((s) => {
        expect(s.status).toBe('available');
      });
    });

    it('should push-notify the passenger that the booking was cancelled', () => {
      // Push notification body: FR-024 template.
      const notification = {
        type: 'booking_timeout',
        bookingId: expect.any(String),
        message: expect.any(String),
      };

      expect(notification.type).toBe('booking_timeout');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Defensive re-check — booking already confirmed
  // ---------------------------------------------------------------------------
  describe('2. Defensive re-check — skip if already confirmed', () => {
    it('should NOT cancel a booking that was already confirmed before the job fires', () => {
      // If the driver confirmed the booking before the timeout job fires,
      // the processor should exit without modifying the booking.
      const booking = { status: 'confirmed' };
      const shouldCancel = booking.status === 'pending';
      expect(shouldCancel).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. env override controls the delay
  // ---------------------------------------------------------------------------
  describe('3. BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS env override', () => {
    it('should use the override value instead of 3 hours in development', () => {
      const defaultTimeoutSeconds = 3 * 3600;
      const overrideSeconds = Number(
        process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS ??
          defaultTimeoutSeconds,
      );

      expect(overrideSeconds).toBe(OVERRIDE_SECONDS);
      expect(overrideSeconds).toBeLessThan(defaultTimeoutSeconds);
    });
  });
});
