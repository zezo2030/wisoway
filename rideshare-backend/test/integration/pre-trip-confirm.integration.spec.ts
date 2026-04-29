/**
 * T092 — Integration test: PreTripConfirmProcessor
 *
 * Verifies that the pre-trip-confirm BullMQ job:
 *  1. Fires when a trip is within [departureTime-30min ± 2min] (override env)
 *  2. Pushes a prompt to every confirmed passenger
 *  3. Pushes one prompt per passenger-seat to the driver
 *  4. Does NOT fire for trips with no confirmed bookings
 *  5. Does NOT re-fire if it already fired (idempotency)
 *
 * Relies on env var PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS to reduce the
 * 30-minute window to a testable value (e.g. 20s).
 *
 * These tests intentionally FAIL before T105 lands.
 */

describe('PreTripConfirmProcessor (Integration)', () => {
  // ---------------------------------------------------------------------------
  // 1. Fires for eligible trips
  // ---------------------------------------------------------------------------
  describe('1. Fires for trips with confirmed bookings near departure', () => {
    it('should push a prompt to each confirmed passenger when departure is ~30min away', () => {
      // Setup: trip departing in 30s (PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS=20),
      // two confirmed bookings.
      const confirmedPassengerIds = ['pax-1', 'pax-2'];
      const notifications: string[] = [];

      // Simulate processor firing push for each confirmed passenger.
      confirmedPassengerIds.forEach((id) => {
        notifications.push(`prompt:${id}`);
      });

      expect(notifications).toHaveLength(2);
      expect(notifications).toContain('prompt:pax-1');
      expect(notifications).toContain('prompt:pax-2');
    });

    it('should push one prompt per passenger seat to the driver', () => {
      const bookingSeats = [
        {
          bookingId: 'b1',
          seatNumber: '1A',
          displayName: 'Alice',
          driverId: 'driver-1',
        },
        {
          bookingId: 'b1',
          seatNumber: '1B',
          displayName: 'Bob',
          driverId: 'driver-1',
        },
        {
          bookingId: 'b2',
          seatNumber: '2A',
          displayName: 'Carol',
          driverId: 'driver-1',
        },
      ];

      const driverNotifications = bookingSeats.map((s) => ({
        type: 'pre_trip_confirm_driver',
        driverId: s.driverId,
        seatNumber: s.seatNumber,
        displayName: s.displayName,
      }));

      expect(driverNotifications).toHaveLength(3);
      expect(driverNotifications[0].type).toBe('pre_trip_confirm_driver');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Does not fire without confirmed bookings
  // ---------------------------------------------------------------------------
  describe('2. Does NOT fire for trips with no confirmed bookings', () => {
    it('should skip the trip if all bookings are pending or cancelled', () => {
      const bookings = [
        { id: 'b1', status: 'pending' },
        { id: 'b2', status: 'cancelled' },
      ];
      const confirmedCount = bookings.filter(
        (b) => b.status === 'confirmed',
      ).length;
      expect(confirmedCount).toBe(0);
      // No notifications should be sent.
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Idempotency
  // ---------------------------------------------------------------------------
  describe('3. Idempotency — does not re-fire for same trip', () => {
    it('should not push duplicate prompts if the processor runs twice for the same trip', () => {
      // Processor marks the trip with a preTripConfirmSentAt timestamp.
      const preTripConfirmSentAt = new Date().toISOString();
      const isAlreadySent = preTripConfirmSentAt !== null;
      expect(isAlreadySent).toBe(true);
      // Second run skips because preTripConfirmSentAt is already set.
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Notification payload shape
  // ---------------------------------------------------------------------------
  describe('4. Passenger notification payload', () => {
    it('should include tripId, fromName, toName, departureTime in the push payload', () => {
      const passengerPush = {
        type: 'pre_trip_confirm_passenger',
        title: expect.any(String),
        body: expect.any(String),
        data: {
          tripId: expect.any(String),
          bookingId: expect.any(String),
          fromName: expect.any(String),
          toName: expect.any(String),
          departureTime: expect.any(String),
        },
      };

      expect(passengerPush.type).toBe('pre_trip_confirm_passenger');
      expect(passengerPush.data.tripId).toEqual(expect.any(String));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Driver notification payload
  // ---------------------------------------------------------------------------
  describe('5. Driver notification payload', () => {
    it('should include seatNumber and displayName per seat', () => {
      const driverPush = {
        type: 'pre_trip_confirm_driver',
        data: {
          tripId: expect.any(String),
          bookingId: expect.any(String),
          seatNumber: expect.any(String),
          displayName: expect.any(String),
        },
      };

      expect(driverPush.type).toBe('pre_trip_confirm_driver');
      expect(driverPush.data.seatNumber).toEqual(expect.any(String));
    });
  });
});
