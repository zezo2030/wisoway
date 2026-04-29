/**
 * T185 — Unit tests for BookingViewerSerializer
 *
 * Coverage targets:
 *  - Admin viewer: always receives raw values regardless of settlement state.
 *  - Settled booking (settledAt IS NOT NULL): PII fully revealed, contact channels enabled.
 *  - Unsettled booking (settledAt IS NULL): PII masked to '***', contact channels disabled.
 *  - Nullable PII fields already null: masking leaves them null (does not replace with '***').
 *  - Missing otherParty: no crash; channels still masked.
 */

import {
  BookingViewerSerializer,
  MaskableBookingView,
  ViewerRole,
} from '../../src/modules/bookings/serializers/booking-viewer.serializer';

const MASK = '***';

const makeSettledBooking = (
  overrides: Partial<MaskableBookingView> = {},
): MaskableBookingView => ({
  settledAt: new Date('2026-01-15T10:00:00Z'),
  chatEnabled: false,
  callEnabled: false,
  otherParty: {
    displayName: 'Ahmad Khalil',
    phone: '+962790000001',
    phoneNumber: '+962790000001',
    photoUrl: 'https://cdn.example.com/photo.jpg',
  },
  ...overrides,
});

const makeUnsettledBooking = (
  overrides: Partial<MaskableBookingView> = {},
): MaskableBookingView => ({
  settledAt: null,
  chatEnabled: false,
  callEnabled: false,
  otherParty: {
    displayName: 'Ahmad Khalil',
    phone: '+962790000001',
    phoneNumber: '+962790000001',
    photoUrl: 'https://cdn.example.com/photo.jpg',
  },
  ...overrides,
});

describe('BookingViewerSerializer', () => {
  // ── Admin viewer ────────────────────────────────────────────────────────────

  describe('admin viewer', () => {
    it('returns raw data unchanged when booking is settled', () => {
      const booking = makeSettledBooking();
      const result = BookingViewerSerializer.serialize(booking, 'admin');
      expect(result).toBe(booking); // same reference — no copy made
    });

    it('returns raw data unchanged when booking is unsettled', () => {
      const booking = makeUnsettledBooking();
      const result = BookingViewerSerializer.serialize(booking, 'admin');
      expect(result).toBe(booking);
    });

    it('does not mask PII fields even when unsettled', () => {
      const booking = makeUnsettledBooking();
      const result = BookingViewerSerializer.serialize(booking, 'admin');
      expect(result.otherParty?.displayName).toBe('Ahmad Khalil');
      expect(result.otherParty?.phone).toBe('+962790000001');
    });
  });

  // ── Settled booking ─────────────────────────────────────────────────────────

  describe('settled booking (settledAt IS NOT NULL)', () => {
    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: reveals PII fields',
      (role) => {
        const booking = makeSettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.otherParty?.displayName).toBe('Ahmad Khalil');
        expect(result.otherParty?.phone).toBe('+962790000001');
        expect(result.otherParty?.phoneNumber).toBe('+962790000001');
        expect(result.otherParty?.photoUrl).toBe(
          'https://cdn.example.com/photo.jpg',
        );
      },
    );

    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: enables chat and call channels',
      (role) => {
        const booking = makeSettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.chatEnabled).toBe(true);
        expect(result.callEnabled).toBe(true);
      },
    );

    it('treats settledAt as a string timestamp as settled', () => {
      const booking = makeSettledBooking({ settledAt: '2026-01-15T10:00:00Z' });
      const result = BookingViewerSerializer.serialize(booking, 'passenger');
      expect(result.chatEnabled).toBe(true);
    });
  });

  // ── Unsettled booking ───────────────────────────────────────────────────────

  describe('unsettled booking (settledAt IS NULL)', () => {
    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: masks displayName',
      (role) => {
        const booking = makeUnsettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.otherParty?.displayName).toBe(MASK);
      },
    );

    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: masks phone',
      (role) => {
        const booking = makeUnsettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.otherParty?.phone).toBe(MASK);
      },
    );

    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: masks phoneNumber',
      (role) => {
        const booking = makeUnsettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.otherParty?.phoneNumber).toBe(MASK);
      },
    );

    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: masks photoUrl',
      (role) => {
        const booking = makeUnsettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.otherParty?.photoUrl).toBe(MASK);
      },
    );

    it.each<ViewerRole>(['passenger', 'driver'])(
      '%s viewer: disables chat and call channels',
      (role) => {
        const booking = makeUnsettledBooking();
        const result = BookingViewerSerializer.serialize(booking, role);
        expect(result.chatEnabled).toBe(false);
        expect(result.callEnabled).toBe(false);
      },
    );

    it('does not replace null PII fields with mask string', () => {
      const booking = makeUnsettledBooking({
        otherParty: {
          displayName: null,
          phone: null,
          phoneNumber: null,
          photoUrl: null,
        },
      });
      const result = BookingViewerSerializer.serialize(booking, 'passenger');
      // Null fields should remain null, not be replaced with '***'
      expect(result.otherParty?.displayName).toBeNull();
      expect(result.otherParty?.phone).toBeNull();
      expect(result.otherParty?.phoneNumber).toBeNull();
      expect(result.otherParty?.photoUrl).toBeNull();
    });

    it('handles missing otherParty without throwing', () => {
      const booking = makeUnsettledBooking({ otherParty: undefined });
      expect(() =>
        BookingViewerSerializer.serialize(booking, 'passenger'),
      ).not.toThrow();
    });

    it('still disables channels when otherParty is absent', () => {
      const booking = makeUnsettledBooking({ otherParty: undefined });
      const result = BookingViewerSerializer.serialize(booking, 'passenger');
      expect(result.chatEnabled).toBe(false);
      expect(result.callEnabled).toBe(false);
    });

    it('preserves non-PII extra fields on otherParty untouched', () => {
      const booking = makeUnsettledBooking({
        otherParty: {
          displayName: 'Ahmad Khalil',
          phone: '+962790000001',
          phoneNumber: '+962790000001',
          photoUrl: 'https://cdn.example.com/photo.jpg',
          rating: 4.8,
          tripCount: 23,
        },
      });
      const result = BookingViewerSerializer.serialize(booking, 'driver');
      expect(result.otherParty?.rating).toBe(4.8);
      expect(result.otherParty?.tripCount).toBe(23);
    });

    it('does not mutate the original booking object', () => {
      const booking = makeUnsettledBooking();
      const originalDisplayName = booking.otherParty?.displayName;
      BookingViewerSerializer.serialize(booking, 'passenger');
      expect(booking.otherParty?.displayName).toBe(originalDisplayName);
    });
  });

  // ── Default viewer (no role passed) ────────────────────────────────────────

  describe('default viewer (role = undefined)', () => {
    it('treats undefined role as non-admin and applies masking when unsettled', () => {
      const booking = makeUnsettledBooking();
      const result = BookingViewerSerializer.serialize(booking);
      expect(result.otherParty?.displayName).toBe(MASK);
      expect(result.chatEnabled).toBe(false);
    });

    it('treats undefined role as non-admin and reveals when settled', () => {
      const booking = makeSettledBooking();
      const result = BookingViewerSerializer.serialize(booking);
      expect(result.otherParty?.displayName).toBe('Ahmad Khalil');
      expect(result.chatEnabled).toBe(true);
    });
  });
});
