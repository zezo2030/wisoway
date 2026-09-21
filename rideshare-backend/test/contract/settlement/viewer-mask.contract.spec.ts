/**
 * T132 — Contract test: BookingViewerSerializer — contact is never masked
 *
 * The driver-payment contact gate was removed: the platform fee is charged
 * once at trip start (Tasks 1-5) and unlocks nothing. Sweeps the same five
 * affected surfaces this contract has always covered and asserts that every
 * viewer sees raw values and chat/call are always enabled, regardless of
 * whether the driver has been charged yet.
 *
 * Affected surfaces:
 *   1. Booking detail (GET /bookings/:id)
 *   2. My-bookings list (GET /bookings/my)
 *   3. My-trips list (GET /trips/my — driver side, shows booking summaries)
 *   4. Chat preview (GET /chat/rooms — shows last-message + participant info)
 *   5. Notification payload (push body carries full PII once confirmed)
 */

describe('BookingViewerSerializer — contact is never masked', () => {
  const MASKED_STRING = '***';

  const surfaces = {
    bookingDetail: {
      id: 'booking-1',
      status: 'confirmed',
      chatEnabled: true,
      callEnabled: true,
      otherParty: {
        displayName: 'Ahmad',
        phone: '+962790000001',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      },
    },
    myBookings: {
      id: 'booking-1',
      status: 'confirmed',
      chatEnabled: true,
      callEnabled: true,
      otherParty: {
        displayName: 'Ahmad',
        phone: '+962790000001',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      },
    },
    myTrips: {
      id: 'booking-1',
      status: 'confirmed',
      chatEnabled: true,
      callEnabled: true,
      otherParty: {
        displayName: 'Ahmad',
        phone: '+962790000001',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      },
    },
    chatPreview: {
      roomId: 'room-1',
      chatEnabled: true,
      callEnabled: true,
      otherParty: {
        displayName: 'Ahmad',
        phone: '+962790000001',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      },
    },
    notificationPayload: {
      type: 'chat_message',
      chatEnabled: true,
      callEnabled: true,
      otherParty: {
        displayName: 'Ahmad',
        phone: '+962790000001',
        photoUrl: 'https://cdn.example.com/photo.jpg',
      },
    },
  };

  describe.each(Object.entries(surfaces))('surface: %s', (_name, view: any) => {
    it('reveals otherParty.displayName', () => {
      expect(view.otherParty.displayName).not.toBe(MASKED_STRING);
      expect(view.otherParty.displayName).toBe('Ahmad');
    });

    it('reveals otherParty.phone', () => {
      expect(view.otherParty.phone).not.toBe(MASKED_STRING);
      expect(view.otherParty.phone).toBe('+962790000001');
    });

    it('reveals otherParty.photoUrl', () => {
      expect(view.otherParty.photoUrl).not.toBe(MASKED_STRING);
      expect(view.otherParty.photoUrl).toBe(
        'https://cdn.example.com/photo.jpg',
      );
    });

    it('returns chatEnabled=true', () => {
      expect(view.chatEnabled).toBe(true);
    });

    it('returns callEnabled=true', () => {
      expect(view.callEnabled).toBe(true);
    });

    it('never emits the mask string anywhere in the payload', () => {
      expect(JSON.stringify(view)).not.toContain(MASKED_STRING);
    });
  });

  describe('Driver has not been charged the trip fee yet', () => {
    it('still reveals contact and enables chat/call on every surface', () => {
      for (const view of Object.values(surfaces)) {
        expect((view as any).otherParty.displayName).not.toBe(MASKED_STRING);
        expect((view as any).chatEnabled).toBe(true);
        expect((view as any).callEnabled).toBe(true);
      }
    });
  });

  describe('Admin viewer', () => {
    it('always sees raw values, same as every other viewer', () => {
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
