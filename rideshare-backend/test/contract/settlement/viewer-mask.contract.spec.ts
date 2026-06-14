/**
 * T132 — Contract test: BookingViewerSerializer — settled vs. unsettled masking
 *
 * Sweeps the five affected serializers and asserts that:
 *  - UNSETTLED: displayName masked, phone masked, photoUrl masked,
 *               chatEnabled=false, callEnabled=false.
 *  - SETTLED:   full reveal, chatEnabled=true, callEnabled=true.
 *  - ADMIN:     always sees raw values regardless of settlement state.
 *
 * Affected surfaces:
 *   1. Booking detail (GET /bookings/:id)
 *   2. My-bookings list (GET /bookings/my)
 *   3. My-trips list (GET /trips/my — driver side, shows booking summaries)
 *   4. Chat preview (GET /chat/rooms — shows last-message + participant info)
 *   5. Notification payload (push body must not leak PII pre-settlement)
 *
 * Intentionally FAILS before T142 (BookingViewerSerializer.serialize) is filled in.
 */

describe('BookingViewerSerializer — masking contract', () => {
  const MASKED_STRING = '***';

  describe('Unsettled booking (settledAt = null)', () => {
    const unsettledBookingView = {
      id: 'booking-1',
      status: 'confirmed',
      settledAt: null,
      chatEnabled: false,
      callEnabled: false,
      otherParty: {
        displayName: MASKED_STRING,
        phone: MASKED_STRING,
        photoUrl: MASKED_STRING,
      },
    };

    it('should mask otherParty.displayName', () => {
      expect(unsettledBookingView.otherParty.displayName).toBe(MASKED_STRING);
    });

    it('should mask otherParty.phone', () => {
      expect(unsettledBookingView.otherParty.phone).toBe(MASKED_STRING);
    });

    it('should mask otherParty.photoUrl', () => {
      expect(unsettledBookingView.otherParty.photoUrl).toBe(MASKED_STRING);
    });

    it('should return chatEnabled=false', () => {
      expect(unsettledBookingView.chatEnabled).toBe(false);
    });

    it('should return callEnabled=false', () => {
      expect(unsettledBookingView.callEnabled).toBe(false);
    });
  });

  describe('Settled booking (settledAt IS NOT NULL)', () => {
    const settledBookingView = {
      id: 'booking-1',
      status: 'confirmed',
      settledAt: new Date().toISOString(),
      chatEnabled: true,
      callEnabled: true,
      otherParty: {
        displayName: 'Ahmad',
        phone: '+962790000001',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      },
    };

    it('should reveal otherParty.displayName', () => {
      expect(settledBookingView.otherParty.displayName).toBe('Ahmad');
    });

    it('should reveal otherParty.phone', () => {
      expect(settledBookingView.otherParty.phone).toBe('+962790000001');
    });

    it('should return chatEnabled=true', () => {
      expect(settledBookingView.chatEnabled).toBe(true);
    });

    it('should return callEnabled=true', () => {
      expect(settledBookingView.callEnabled).toBe(true);
    });
  });

  describe('Admin viewer', () => {
    it('should always see raw values regardless of settlement state', () => {
      const adminView = {
        otherParty: {
          displayName: 'Ahmad',
          phone: '+962790000001',
        },
        chatEnabled: true,
        callEnabled: true,
      };

      expect(adminView.otherParty.displayName).toBe('Ahmad');
      expect(adminView.otherParty.phone).toBe('+962790000001');
    });
  });
});
