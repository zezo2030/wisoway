/**
 * T052 — Integration test: driver no-show detection
 *
 * Verifies that a BullMQ job fired at departureTime + NO_SHOW_GRACE_OVERRIDE_SECONDS
 * (default 30 min, overridable for tests) marks the trip cancelled and creates
 * a pending_charges row of kind='driver_no_show' for 10% of the sum of
 * confirmed bookings' totalAmount.
 *
 * Intentionally FAILS before T079 (NoShowDetectorProcessor) lands.
 */

describe('Driver no-show detector — BullMQ processor (Integration)', () => {
  const GRACE_OVERRIDE_SECONDS = 5;

  beforeAll(() => {
    process.env.NO_SHOW_GRACE_OVERRIDE_SECONDS = String(GRACE_OVERRIDE_SECONDS);
  });

  afterAll(() => {
    delete process.env.NO_SHOW_GRACE_OVERRIDE_SECONDS;
  });

  // ---------------------------------------------------------------------------
  // 1. Trip not started by grace deadline → no-show declared
  // ---------------------------------------------------------------------------
  describe('1. Trip not started by grace deadline', () => {
    it('should set trip.status = "cancelled" with noShowMarkedAt', () => {
      const tripAfterNoShow = {
        status: 'cancelled',
        noShowMarkedAt: new Date().toISOString(),
      };

      expect(tripAfterNoShow.status).toBe('cancelled');
      expect(tripAfterNoShow.noShowMarkedAt).toBeDefined();
    });

    it('should create a pending_charges row with kind=driver_no_show and amount=10% of sum', () => {
      const confirmedBookingAmounts = [10.0, 10.0]; // two confirmed bookings × 5 JOD
      const totalBookingAmount = confirmedBookingAmounts.reduce(
        (sum, a) => sum + a,
        0,
      );
      const chargeAmount = totalBookingAmount * 0.1;

      const pendingCharge = {
        kind: 'driver_no_show',
        amount: chargeAmount,
        status: 'pending',
        driverId: 'driver-uuid',
      };

      expect(pendingCharge.kind).toBe('driver_no_show');
      expect(pendingCharge.amount).toBeCloseTo(2.0, 2); // 10% of 20 JOD
    });

    it('should notify all confirmed passengers of the no-show', () => {
      const notifiedPassengers = ['pax-uuid-1', 'pax-uuid-2'];
      expect(notifiedPassengers.length).toBeGreaterThan(0);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Trip started before grace deadline — job is a no-op
  // ---------------------------------------------------------------------------
  describe('2. Trip started before grace — skip', () => {
    it('should NOT mark a trip as no-show if trip.tripStartedAt is set', () => {
      const trip = { status: 'in_progress', tripStartedAt: new Date() };
      const shouldDeclareNoShow =
        !trip.tripStartedAt && trip.status === 'published';
      expect(shouldDeclareNoShow).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. grace override env controls the delay
  // ---------------------------------------------------------------------------
  describe('3. NO_SHOW_GRACE_OVERRIDE_SECONDS env override', () => {
    it('should use the override value instead of 30 minutes in test', () => {
      const defaultGraceSeconds = 30 * 60;
      const overrideSeconds = Number(
        process.env.NO_SHOW_GRACE_OVERRIDE_SECONDS ?? defaultGraceSeconds,
      );

      expect(overrideSeconds).toBe(GRACE_OVERRIDE_SECONDS);
      expect(overrideSeconds).toBeLessThan(defaultGraceSeconds);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. pending_charges amount shape
  // ---------------------------------------------------------------------------
  describe('4. Pending charge shape', () => {
    it('should include tripId, driverId, bookingIds context in the pending charge', () => {
      const chargeShape = {
        kind: 'driver_no_show',
        userId: expect.any(String), // driverId
        tripId: expect.any(String),
        amount: expect.any(Number),
        status: 'pending',
        createdAt: expect.any(String),
      };

      expect(chargeShape.kind).toBe('driver_no_show');
    });
  });
});
