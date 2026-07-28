/**
 * Platform-wide error code constants.
 *
 * These string literals are used as the `code` field in error response bodies
 * across all API surfaces (backend HTTP, WebSocket close events, mobile
 * localisation keys).  Keeping them in one place prevents typos and makes
 * it easy to cross-reference contracts.
 *
 * Grouped by domain area (matches the six branches in plan.md).
 */
export const ErrorCodes = {
  // ── Auth / Device safety (US1 / 009-auth-hardening) ────────────────────────

  /** Driver or passenger submitted a location update flagged as mocked. */
  LOCATION_INTEGRITY_VIOLATION: 'LOCATION_INTEGRITY_VIOLATION',

  /** The requesting user account has been banned by an admin. */
  ACCOUNT_BANNED: 'ACCOUNT_BANNED',

  /** The requesting user account is restricted (write operations blocked). */
  ACCOUNT_RESTRICTED: 'ACCOUNT_RESTRICTED',

  /** Driver attempted to publish a trip or get approved without a profile photo. */
  PROFILE_PHOTO_REQUIRED: 'PROFILE_PHOTO_REQUIRED',

  /** Driver attempted to publish a trip while owing one or more pending charges. */
  OUTSTANDING_CHARGES: 'OUTSTANDING_CHARGES',

  /** Admin approval has not been granted to this driver yet. */
  DRIVER_REQUIRES_APPROVAL: 'DRIVER_REQUIRES_APPROVAL',

  /** Caller attempted to delete (revoke) their own current device session. */
  SELF_REVOKE_USE_LOGOUT: 'SELF_REVOKE_USE_LOGOUT',

  // ── Booking lifecycle (US2 / 010-booking-lifecycle) ─────────────────────────

  /** One or more requested seats are already taken by another booking. */
  SEATS_TAKEN: 'SEATS_TAKEN',

  /**
   * The requested seat arrangement violates the gender-adjacency rule
   * (a female passenger cannot be assigned adjacent to a male passenger
   * unless her companion group already occupies the adjacent seat).
   */
  GENDER_ADJACENCY_VIOLATION: 'GENDER_ADJACENCY_VIOLATION',

  /**
   * The auto-pick algorithm could not find a valid seat arrangement that
   * satisfies adjacency constraints and available capacity.
   */
  NO_VALID_ARRANGEMENT: 'NO_VALID_ARRANGEMENT',

  /** Cancellation request is outside the allowed time window. */
  CANCELLATION_WINDOW_CLOSED: 'CANCELLATION_WINDOW_CLOSED',

  // ── Trip time-flow (US3 / 011-trip-time-flow) ────────────────────────────────

  /**
   * An action was attempted outside its permitted time window
   * (e.g. Start Trip called more than 15 minutes before departure).
   */
  TIMING_WINDOW: 'TIMING_WINDOW',

  // ── Settlement & calls (US5 / 013-settle-and-call) ───────────────────────────

  /** Driver attempted to mark-paid a booking that is already settled. */
  ALREADY_SETTLED: 'ALREADY_SETTLED',

  /** Passenger or driver attempted an action that requires the booking to be confirmed first. */
  BOOKING_NOT_CONFIRMED: 'BOOKING_NOT_CONFIRMED',

  /** Action requires the booking to be settled (mark-paid) first. */
  BOOKING_NOT_SETTLED: 'BOOKING_NOT_SETTLED',

  /** Driver attempted to unsettle a booking outside the 5-minute grace window. */
  GRACE_EXPIRED: 'GRACE_EXPIRED',

  /**
   * Driver or passenger attempted to reverse a settlement after either party
   * has already used the contact (sent a chat message or made a call).
   */
  CONTACT_ALREADY_USED: 'CONTACT_ALREADY_USED',

  /** In-app call requested but the Twilio proxy number pool is exhausted. */
  NO_PROXY_NUMBERS_AVAILABLE: 'NO_PROXY_NUMBERS_AVAILABLE',

  // ── Admin / shared (US6 / 014-admin-and-support, shared) ─────────────────────

  /** Admin or system tried to perform an action that was already decided. */
  ALREADY_DECIDED: 'ALREADY_DECIDED',

  /** Only the trip's driver may perform this action. */
  NOT_TRIP_DRIVER: 'NOT_TRIP_DRIVER',

  /**
   * A new phone number or device identifier that is already registered to
   * another account was submitted for linking.
   */
  CONTACT_ALREADY_USED_BY_OTHER: 'CONTACT_ALREADY_USED_BY_OTHER',

  // ── Presence confirmation (012-passenger-presence-confirmation) ─────────────

  /**
   * Presence confirmation attempted outside its window (driver: departure − 30m
   * until settlement; passenger: departure − 60m until departure + 30m).
   */
  PRESENCE_WINDOW_CLOSED: 'PRESENCE_WINDOW_CLOSED',

  /** The trip's fee has already been settled — the roster is now immutable. */
  PRESENCE_ALREADY_SETTLED: 'PRESENCE_ALREADY_SETTLED',

  /** A submitted seat number does not belong to the referenced booking. */
  PRESENCE_SEAT_NOT_FOUND: 'PRESENCE_SEAT_NOT_FOUND',

  /**
   * Wallet balance minus funds reserved by active holds is not enough to place
   * a new hold.
   */
  INSUFFICIENT_AVAILABLE_BALANCE: 'INSUFFICIENT_AVAILABLE_BALANCE',

  /** Settlement or release referenced a hold that does not exist or is closed. */
  HOLD_NOT_FOUND: 'HOLD_NOT_FOUND',

  /** Driver wallet balance is negative — blocked from publishing / going online. */
  NEGATIVE_WALLET_BALANCE: 'NEGATIVE_WALLET_BALANCE',
} as const;

/** Union type of all error code strings. */
export type ErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];
