// Enums: Rideshare Admin Dashboard
// Source: data-model.md
// Using const objects for erasableSyntaxOnly compatibility

export const UserRole = {
  PASSENGER: 'passenger',
  DRIVER: 'driver',
  ADMIN: 'admin',
} as const

export type UserRole = typeof UserRole[keyof typeof UserRole]

export const TripStatus = {
  ACTIVE: 'active',
  HIDDEN: 'hidden',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled',
  EXPIRED: 'expired',
} as const

export type TripStatus = typeof TripStatus[keyof typeof TripStatus]

export const BookingStatus = {
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  CANCELLED: 'cancelled',
  COMPLETED: 'completed',
} as const

export type BookingStatus = typeof BookingStatus[keyof typeof BookingStatus]

export const PaymentStatus = {
  PENDING: 'pending',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  REFUNDED: 'refunded',
} as const

export type PaymentStatus = typeof PaymentStatus[keyof typeof PaymentStatus]

export const PaymentMethod = {
  WALLET: 'wallet',
  PAYMOB: 'paymob',
  MANUAL: 'manual',
  COMMUNICATION_FEE: 'communication_fee',
  CLIQ_A2A: 'cliq_a2a',
} as const

export type PaymentMethod = typeof PaymentMethod[keyof typeof PaymentMethod]

export const PaymentType = {
  TRIP: 'trip',
  COMMUNICATION_FEE: 'communication_fee',
  WALLET_TOPUP: 'wallet_topup',
  WALLET_TRIP_CHARGE: 'wallet_trip_charge',
} as const

export type PaymentType = typeof PaymentType[keyof typeof PaymentType]

export const SeatStatus = {
  AVAILABLE: 'available',
  BOOKED: 'booked',
  LOCKED: 'locked',
} as const

export type SeatStatus = typeof SeatStatus[keyof typeof SeatStatus]

export const Currency = {
  EGP: 'EGP',
  JOD: 'JOD',
  SAR: 'SAR',
  AED: 'AED',
  QAR: 'QAR',
} as const

export type Currency = typeof Currency[keyof typeof Currency]

export const Gender = {
  MALE: 'male',
  FEMALE: 'female',
} as const

export type Gender = typeof Gender[keyof typeof Gender]

export const ReportType = {
  REVENUE: 'revenue',
  USERS: 'users',
  TRIPS: 'trips',
} as const

export type ReportType = typeof ReportType[keyof typeof ReportType]

export const WalletAccountType = {
  DRIVER: 'driver',
  RIDER: 'rider',
  SYSTEM: 'system',
} as const

export type WalletAccountType = typeof WalletAccountType[keyof typeof WalletAccountType]

export const WalletEntryDirection = {
  DEBIT: 'debit',
  CREDIT: 'credit',
} as const

export type WalletEntryDirection = typeof WalletEntryDirection[keyof typeof WalletEntryDirection]

export const WalletTransactionType = {
  TOPUP: 'topup',
  TRIP_DEBIT: 'trip_debit',
  TRIP_PAYMENT: 'trip_payment',
  REFUND: 'refund',
  PAYOUT: 'payout',
  ADJUSTMENT: 'adjustment',
  HOLD: 'hold',
  RELEASE_HOLD: 'release_hold',
} as const

export type WalletTransactionType = typeof WalletTransactionType[keyof typeof WalletTransactionType]
