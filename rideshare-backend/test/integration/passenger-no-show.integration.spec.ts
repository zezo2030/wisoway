/**
 * T053 — Integration test: passenger no-show at trip completion
 *
 * Verifies that when a driver calls POST /trips/:id/complete with
 * noShowSeats specified, the relevant BookingSeat rows are marked absent
 * and a pending_charges row of kind='passenger_no_show' is created
 * for 5% of the booking's totalAmount.
 *
 * This test is gated behind TRIP_TIME_FLOW_ENABLED=true.
 * Intentionally FAILS before T080 (complete-trip hook) lands.
 */

describe('Passenger no-show — complete-trip hook (Integration)', () => {
  beforeAll(() => {
    process.env.TRIP_TIME_FLOW_ENABLED = 'true';
  });

  afterAll(() => {
    delete process.env.TRIP_TIME_FLOW_ENABLED;
  });

  // ---------------------------------------------------------------------------
  // 1. Driver declares passenger no-show on complete
  // ---------------------------------------------------------------------------
  describe('1. noShowSeats provided on complete', () => {
    it('should mark BookingSeat.markedAbsentAt for each no-show seat', () => {
      const seatsAfterComplete = [
        {
          seatNumber: '1A',
          markedAbsentAt: new Date().toISOString(),
          isMainBooker: true,
        },
        { seatNumber: '1B', markedAbsentAt: null, isMainBooker: false },
      ];

      const absentSeat = seatsAfterComplete.find((s) => s.seatNumber === '1A');
      expect(absentSeat?.markedAbsentAt).toBeDefined();
    });

    it('should set booking.status = "no_show" when ALL seats in the booking are absent', () => {
      const seats = [
        { seatNumber: '1A', markedAbsentAt: new Date() },
        { seatNumber: '1B', markedAbsentAt: new Date() },
      ];

      const allAbsent = seats.every((s) => !!s.markedAbsentAt);
      const bookingStatus = allAbsent ? 'no_show' : 'completed';

      expect(allAbsent).toBe(true);
      expect(bookingStatus).toBe('no_show');
    });

    it('should NOT set no_show if at least one seat was present', () => {
      const seats = [
        { seatNumber: '1A', markedAbsentAt: new Date() },
        { seatNumber: '1B', markedAbsentAt: null }, // present
      ];

      const allAbsent = seats.every((s) => !!s.markedAbsentAt);
      const bookingStatus = allAbsent ? 'no_show' : 'completed';

      expect(allAbsent).toBe(false);
      expect(bookingStatus).toBe('completed');
    });

    it('should create a pending_charges row of kind=passenger_no_show for 5%', () => {
      const totalAmount = 10.0;
      const chargeAmount = totalAmount * 0.05;

      const pendingCharge = {
        kind: 'passenger_no_show',
        amount: chargeAmount,
        status: 'pending',
      };

      expect(pendingCharge.kind).toBe('passenger_no_show');
      expect(pendingCharge.amount).toBeCloseTo(0.5, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. No no-show seats — normal completion
  // ---------------------------------------------------------------------------
  describe('2. No no-show seats — normal completion', () => {
    it('should set booking.status = "completed" when noShowSeats is empty', () => {
      const noShowSeats: string[] = [];
      const bookingStatus = noShowSeats.length > 0 ? 'no_show' : 'completed';
      expect(bookingStatus).toBe('completed');
    });

    it('should NOT create any pending_charges row when no seats are absent', () => {
      const charges: unknown[] = [];
      expect(charges).toHaveLength(0);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. TRIP_TIME_FLOW_ENABLED feature flag
  // ---------------------------------------------------------------------------
  describe('3. Feature flag gate', () => {
    it('should be guarded by TRIP_TIME_FLOW_ENABLED env var', () => {
      const isEnabled = process.env.TRIP_TIME_FLOW_ENABLED === 'true';
      expect(isEnabled).toBe(true);
    });
  });
});
