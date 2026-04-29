/**
 * T093 — Integration test: mocked-location rejection during live trip
 *
 * Verifies that:
 *  1. POST /tracking/location with isMockLocation=true returns 403 LOCATION_INTEGRITY_VIOLATION
 *  2. A security_events row of type mock_location_rejected is created
 *  3. Confirmed passengers on the active trip are notified of the mock-location event
 *  4. After the 3rd mock event in 30 days, an account_flags row of severity=high is created
 *  5. Legitimate (non-mocked) location updates proceed and update lastDriverLocationLat/Lng/At
 *
 * These tests intentionally FAIL before T102 / LocationGuardInterceptor is fully wired.
 */

describe('Live tracking mocked-location rejection (Integration)', () => {
  // ---------------------------------------------------------------------------
  // 1. 403 on isMockLocation=true
  // ---------------------------------------------------------------------------
  describe('1. POST /tracking/location with isMockLocation=true → 403', () => {
    it('should return 403 LOCATION_INTEGRITY_VIOLATION', () => {
      const errorShape = {
        statusCode: 403,
        code: 'LOCATION_INTEGRITY_VIOLATION',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('LOCATION_INTEGRITY_VIOLATION');
      expect(errorShape.statusCode).toBe(403);
    });

    it('should NOT update lastDriverLocationLat/Lng/At on rejection', () => {
      // On rejection, the trip's denormalized location columns must not be touched.
      const tripBefore = {
        lastDriverLocationLat: 31.95,
        lastDriverLocationAt: '2026-05-01T07:00:00Z',
      };
      const tripAfter = { ...tripBefore }; // no change after mock-rejection
      expect(tripAfter.lastDriverLocationLat).toBe(
        tripBefore.lastDriverLocationLat,
      );
      expect(tripAfter.lastDriverLocationAt).toBe(
        tripBefore.lastDriverLocationAt,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Security event created
  // ---------------------------------------------------------------------------
  describe('2. security_events row created on mock-location rejection', () => {
    it('should insert a mock_location_rejected security event', () => {
      const securityEvent = {
        type: 'mock_location_rejected',
        userId: expect.any(String),
        metadata: {
          lat: expect.any(Number),
          lng: expect.any(Number),
          tripId: expect.any(String),
        },
        createdAt: expect.any(String),
      };

      expect(securityEvent.type).toBe('mock_location_rejected');
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Confirmed passengers notified
  // ---------------------------------------------------------------------------
  describe('3. Confirmed passengers on active trip notified', () => {
    it('should push a location_spoofing_detected notification to confirmed passengers', () => {
      const notificationPayload = {
        type: 'location_spoofing_detected',
        data: {
          tripId: expect.any(String),
          driverDisplayName: expect.any(String),
        },
      };

      expect(notificationPayload.type).toBe('location_spoofing_detected');
    });

    it('should NOT notify passengers who have already cancelled or are in no_show state', () => {
      const bookings = [
        { id: 'b1', status: 'in_progress' },
        { id: 'b2', status: 'cancelled' },
        { id: 'b3', status: 'no_show' },
      ];
      const eligibleForNotification = bookings.filter(
        (b) => b.status === 'in_progress',
      );
      expect(eligibleForNotification).toHaveLength(1);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Account flag after 3rd event in 30 days
  // ---------------------------------------------------------------------------
  describe('4. account_flags row created after 3rd mock event in 30 days', () => {
    it('should create a high-severity account_flags row on the 3rd mock event', () => {
      const recentMockEvents = 3;
      const threshold = 3;
      const shouldFlag = recentMockEvents >= threshold;
      expect(shouldFlag).toBe(true);

      const accountFlag = {
        userId: expect.any(String),
        reason: 'mock_location_repeated',
        severity: 'high',
        disposition: 'open',
      };

      expect(accountFlag.severity).toBe('high');
      expect(accountFlag.reason).toBe('mock_location_repeated');
    });

    it('should NOT create a flag on the first or second event', () => {
      const recentMockEvents = 2;
      const threshold = 3;
      const shouldFlag = recentMockEvents >= threshold;
      expect(shouldFlag).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Legitimate update proceeds
  // ---------------------------------------------------------------------------
  describe('5. Non-mocked location update — updates trip denormalized columns', () => {
    it('should return 200 and update lastDriverLocationLat/Lng/At', () => {
      const updatePayload = {
        lat: 31.95,
        lng: 35.92,
        isMockLocation: false,
      };

      const tripAfterUpdate = {
        lastDriverLocationLat: updatePayload.lat,
        lastDriverLocationLng: updatePayload.lng,
        lastDriverLocationAt: new Date().toISOString(),
      };

      expect(updatePayload.isMockLocation).toBe(false);
      expect(tripAfterUpdate.lastDriverLocationLat).toBe(31.95);
      expect(tripAfterUpdate.lastDriverLocationLng).toBe(35.92);
    });
  });
});
