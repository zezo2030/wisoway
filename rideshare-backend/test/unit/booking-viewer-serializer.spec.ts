/**
 * T185 — Unit tests for BookingViewerSerializer
 *
 * Contact details are no longer gated behind a driver payment — the platform
 * fee is charged at trip start and unlocks nothing. This spec asserts the
 * inverse of the old masking contract: every viewer always sees the raw
 * otherParty fields and chat/call are always enabled.
 */

import { BookingViewerSerializer } from '../../src/modules/bookings/serializers/booking-viewer.serializer';

describe('BookingViewerSerializer', () => {
  const raw = {
    chatEnabled: false,
    callEnabled: false,
    otherParty: {
      displayName: 'أحمد محمود',
      phone: '0790000000',
      phoneNumber: '+962790000000',
      photoUrl: 'https://cdn/x.jpg',
    },
  };

  it('reveals contact details to the driver with no payment', () => {
    const out = BookingViewerSerializer.serialize({ ...raw }, 'driver');

    expect(out.otherParty?.displayName).toBe('أحمد محمود');
    expect(out.otherParty?.phone).toBe('0790000000');
    expect(out.otherParty?.phoneNumber).toBe('+962790000000');
    expect(out.otherParty?.photoUrl).toBe('https://cdn/x.jpg');
  });

  it('enables chat and call for every viewer role', () => {
    for (const role of ['driver', 'passenger', 'admin'] as const) {
      const out = BookingViewerSerializer.serialize({ ...raw }, role);
      expect(out.chatEnabled).toBe(true);
      expect(out.callEnabled).toBe(true);
    }
  });

  it('never emits the *** mask', () => {
    const out = BookingViewerSerializer.serialize({ ...raw }, 'driver');
    expect(JSON.stringify(out)).not.toContain('***');
  });
});
