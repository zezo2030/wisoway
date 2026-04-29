/**
 * BookingViewerSerializer — Phase 7 (US5 / 013-settle-and-call) implementation.
 *
 * Masking contract:
 *  - UNSETTLED (settledAt IS NULL):
 *      • otherParty.displayName  → '***'
 *      • otherParty.phone        → '***'
 *      • otherParty.phoneNumber  → '***'
 *      • otherParty.photoUrl     → '***'
 *      • chatEnabled             → false
 *      • callEnabled             → false
 *  - SETTLED (settledAt IS NOT NULL): full reveal; chatEnabled/callEnabled = true.
 *  - ADMIN viewer: always sees raw values regardless of settlement state.
 */

export type ViewerRole = 'passenger' | 'driver' | 'admin';

const MASK = '***';

/** Minimum shape the serializer needs to make masking decisions. */
export interface MaskableBookingView {
  settledAt?: Date | string | null;
  chatEnabled?: boolean;
  callEnabled?: boolean;
  /** Driver-side: the passenger's contact details. */
  otherParty?: {
    displayName?: string | null;
    phone?: string | null;
    phoneNumber?: string | null;
    photoUrl?: string | null;
    [key: string]: unknown;
  };
}

export class BookingViewerSerializer {
  /**
   * Apply settlement-based masking to a booking response object.
   *
   * @param data    Raw booking data to be returned to the client.
   * @param viewer  Role of the requesting user.
   * @returns       Data with PII fields masked when the booking is unsettled.
   */
  static serialize<T extends MaskableBookingView>(
    data: T,
    viewer?: ViewerRole,
  ): T {
    // Admins always see raw values.
    if (viewer === 'admin') return data;

    const settled = data.settledAt != null;

    if (settled) {
      return {
        ...data,
        chatEnabled: true,
        callEnabled: true,
      };
    }

    // Unsettled — mask PII and disable contact channels.
    const masked: T = {
      ...data,
      chatEnabled: false,
      callEnabled: false,
    };

    if (masked.otherParty) {
      masked.otherParty = {
        ...masked.otherParty,
        displayName:
          masked.otherParty.displayName != null
            ? MASK
            : masked.otherParty.displayName,
        phone: masked.otherParty.phone != null ? MASK : masked.otherParty.phone,
        phoneNumber:
          masked.otherParty.phoneNumber != null
            ? MASK
            : masked.otherParty.phoneNumber,
        photoUrl:
          masked.otherParty.photoUrl != null
            ? MASK
            : masked.otherParty.photoUrl,
      };
    }

    return masked;
  }
}
