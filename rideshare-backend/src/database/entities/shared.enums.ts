export enum PgUserRole {
  PASSENGER = 'passenger',
  DRIVER = 'driver',
  ADMIN = 'admin',
}

export enum TripStatus {
  ACTIVE = 'active',
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
