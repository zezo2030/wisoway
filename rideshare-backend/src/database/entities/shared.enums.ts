export enum PgUserRole {
  PASSENGER = 'passenger',
  DRIVER = 'driver',
  ADMIN = 'admin',
}

export enum TripStatus {
  /**
   * @deprecated Phase 9 / T180 — shim dropped.
   * Migration 008.06 converted all 'active' rows to 'published'.
   * This value is retained in the enum only to avoid breaking any in-flight
   * code that still references it; all new code MUST use PUBLISHED.
   */
  ACTIVE = 'active',
  DRAFT = 'draft',
  PUBLISHED = 'published',
  FULLY_BOOKED = 'fully_booked',
  IN_PROGRESS = 'in_progress',
  HIDDEN = 'hidden',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
}

export enum WalletAccountType {
  DRIVER = 'driver',
  RIDER = 'rider',
  SYSTEM = 'system',
}

export enum WalletTransactionType {
  TOPUP = 'topup',
  TRIP_DEBIT = 'trip_debit',
  TRIP_PAYMENT = 'trip_payment',
  REFUND = 'refund',
  PAYOUT = 'payout',
  ADJUSTMENT = 'adjustment',
  HOLD = 'hold',
  RELEASE_HOLD = 'release_hold',
}

export enum WalletEntryDirection {
  DEBIT = 'debit',
  CREDIT = 'credit',
}

export enum WalletTransactionStatus {
  PENDING = 'pending',
  POSTED = 'posted',
  FAILED = 'failed',
  REVERSED = 'reversed',
}

export enum PayoutStatus {
  PENDING = 'pending',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  PAID = 'paid',
}

export enum NotificationChannel {
  IN_APP = 'in_app',
  PUSH = 'push',
}
