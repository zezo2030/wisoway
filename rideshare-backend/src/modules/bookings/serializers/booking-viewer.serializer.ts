/**
 * BookingViewerSerializer
 *
 * Contact details are no longer gated behind a driver payment — the platform
 * fee is charged at trip start and unlocks nothing. This serializer is kept as
 * the single seam where a future access rule would live; today it only asserts
 * that chat and call are enabled for every viewer.
 */

export type ViewerRole = 'passenger' | 'driver' | 'admin';

/** Minimum shape the serializer touches. */
export interface MaskableBookingView {
  chatEnabled?: boolean;
  callEnabled?: boolean;
  otherParty?: {
    displayName?: string | null;
    phone?: string | null;
    phoneNumber?: string | null;
    photoUrl?: string | null;
    [key: string]: unknown;
  };
}

export class BookingViewerSerializer {
  static serialize<T extends MaskableBookingView>(
    data: T,
    _viewer?: ViewerRole,
  ): T {
    return {
      ...data,
      chatEnabled: true,
      callEnabled: true,
    };
  }
}
