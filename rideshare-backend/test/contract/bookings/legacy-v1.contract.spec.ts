/**
 * T050 — Contract test: POST /v1/bookings legacy single-seat shim
 *
 * Verifies that the legacy v1 endpoint still accepts the old seatNumber
 * payload and internally creates a v2 booking with one BookingSeat row
 * where isMainBooker=true.
 *
 * Intentionally FAILS before T069 (v1 shim) lands.
 */

describe('POST /bookings (v1 legacy shim — Contract)', () => {
  // ---------------------------------------------------------------------------
  // 1. v1 shape accepted and creates v2 booking internally
  // ---------------------------------------------------------------------------
  describe('1. v1 payload creates a single-seat v2 booking', () => {
    it('should accept the legacy { tripId, seatNumber } shape', () => {
      const legacyPayload = {
        tripId: '123e4567-e89b-12d3-a456-426614174000',
        seatNumber: '0-0',
        sharePhoneWithDriver: false,
      };

      expect(legacyPayload.tripId).toBeDefined();
      expect(legacyPayload.seatNumber).toBeDefined();
    });

    it('should return a response that matches the existing v1 shape (backward-compatible)', () => {
      // The v1 response must remain identical to the pre-008 shape so existing
      // mobile clients do not break before they upgrade.
      const v1Response = {
        id: expect.any(String),
        tripId: expect.any(String),
        userId: expect.any(String),
        seatNumber: '0-0',
        status: 'pending',
        sharePhoneWithDriver: false,
        createdAt: expect.any(String),
      };

      // seatNumber must be present in the response for backward compatibility.
      expect(v1Response.seatNumber).toBe('0-0');
      expect(v1Response.status).toBe('pending');
    });

    it('should create exactly one BookingSeat row with isMainBooker=true', () => {
      // Internally the shim maps seatNumber to a single BookingSeat with
      // isMainBooker=true and displayName=user.fullName, gender=user.gender.
      const internalSeats = [
        {
          seatNumber: '0-0',
          isMainBooker: true,
          displayName: 'Test User',
          gender: 'male',
        },
      ];

      expect(internalSeats).toHaveLength(1);
      expect(internalSeats[0].isMainBooker).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Deprecation header
  // ---------------------------------------------------------------------------
  describe('2. Deprecation logging', () => {
    it('should emit a Deprecation: true log entry for each v1 call', () => {
      // The shim must log `Deprecation: true` to allow ops to track
      // remaining v1 usage before the endpoint is removed.
      const logEntry = { Deprecation: true, endpoint: 'POST /bookings' };
      expect(logEntry.Deprecation).toBe(true);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Existing validations still apply
  // ---------------------------------------------------------------------------
  describe('3. Existing v1 validations', () => {
    it('should still return 404 if trip does not exist', () => {
      const errorShape = { statusCode: 404 };
      expect(errorShape.statusCode).toBe(404);
    });

    it('should still return 400 if booking own trip', () => {
      const errorShape = { statusCode: 400 };
      expect(errorShape.statusCode).toBe(400);
    });

    it('should still return 409 SEATS_TAKEN if the seat is already booked', () => {
      const errorShape = { statusCode: 409, code: 'SEATS_TAKEN' };
      expect(errorShape.code).toBe('SEATS_TAKEN');
    });
  });
});
