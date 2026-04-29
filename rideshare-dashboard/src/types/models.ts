// Models: Rideshare Admin Dashboard
// Source: data-model.md

import type {
  UserRole,
  TripStatus,
  BookingStatus,
  PaymentStatus,
  PaymentMethod,
  PaymentType,
  SeatStatus,
  Currency,
  Gender,
  PendingChargeKind,
  PendingChargeStatus,
} from './enums'

// Core Entities

export interface User {
  _id: string
  name: string
  email?: string
  phoneNumber?: string
  role: UserRole
  gender?: Gender
  photoUrl?: string
  isActive: boolean
  isPhoneVerified: boolean
  isEmailVerified: boolean
  isDriverApproved: boolean
  rating: number
  totalRatings: number
  provider: 'email' | 'google' | 'facebook' | 'phone'
  providerId?: string
  fcmToken?: string
  createdAt: string
  updatedAt: string
}

export interface Vehicle {
  _id: string
  driverId: string | UserSummary
  vehicleType: string
  model: string
  plateNumber: string
  seats: number
  licenseImageUrl: string
  vehicleLicenseImageUrl: string
  isVerified: boolean
  createdAt: string
  updatedAt: string
}

export interface Location {
  name: string
  latitude: number
  longitude: number
  address?: string
}

export interface SeatLayout {
  rows: number
  seatsPerRow: number
  preventGenderMixing: boolean
  /** Irregular rows (e.g. [1, 3, 2]); when set, defines row widths instead of uniform seatsPerRow. */
  seatsPerRowList?: number[] | null
}

export interface Seat {
  seatNumber: number
  status: SeatStatus
  passengerId?: string
  passengerGender?: Gender
}

export interface Trip {
  _id: string
  id?: string
  driverId: string | UserSummary
  driverName?: string
  from?: Location | string
  to?: Location | string
  fromName?: string
  toName?: string
  departureTime: string
  price: number
  currency: Currency
  totalSeats: number
  availableSeats: number
  status: TripStatus
  seatLayout: SeatLayout
  seats: Seat[]
  communicationFeeStatus: 'not_paid' | 'paid'
  carImageUrl?: string
  isVisible: boolean
  distanceKm?: number
  /** Intermediate stops along the route (up to 5). */
  stops?: TripStop[]
  /** Free-text driver notes visible to passengers. */
  notes?: string
  /** ID of the recurrence rule that generated this trip, if any. */
  recurrenceRuleId?: string
  createdAt: string
  updatedAt: string
}

export interface TripStop {
  name: string
  lat: number
  lng: number
  address?: string
  order: number
  note?: string
}

export interface BookingSeat {
  id: string
  bookingId: string
  seatNumber: string
  displayName: string
  gender: Gender
  isMainBooker: boolean
  markedAbsentAt?: string
  createdAt: string
}

export interface Booking {
  _id: string
  userId: string | UserSummary
  tripId: string | TripSummary
  /** Legacy v1 single-seat field — nullable in v2 bookings. */
  seatNumber: string | null
  /** v2 multi-seat rows. */
  seats?: BookingSeat[]
  seatCount?: number
  totalAmount?: number
  status: BookingStatus
  expiresAt?: string
  rejectedAt?: string
  rejectionReason?: string
  hasDriverPaidToContact: boolean
  sharePhoneWithDriver: boolean
  /** Phase 7 settlement fields */
  settledAt?: string | null
  settlementGraceUntil?: string | null
  cancellationReason?: string
  cancelledAt?: string
  cancelledBy?: 'passenger' | 'driver' | 'system'
  createdAt: string
  updatedAt: string
}

/** Phase 7 — settlement audit entry */
export interface SettlementAudit {
  id: string
  bookingId: string
  action: 'mark_paid' | 'unmark_paid' | 'admin_revert'
  actorId: string | UserSummary
  reason?: string | null
  createdAt: string
}

export interface PendingCharge {
  id: string
  userId: string | UserSummary
  bookingId?: string | BookingSummary
  kind: PendingChargeKind
  status: PendingChargeStatus
  amount: number
  currency: string
  collectedAt?: string
  waivedAt?: string
  waivedBy?: string
  createdAt: string
  updatedAt: string
}

export interface Payment {
  _id: string
  id?: string
  userId: string | UserSummary
  tripId?: string | TripSummary
  bookingId?: string | BookingSummary
  amount: number
  currency: string
  method: PaymentMethod
  paymentType: PaymentType
  status: PaymentStatus
  proofImageUrl?: string
  walletNumber?: string
  transactionId?: string
  paymentGatewayRef?: string
  adminNote?: string
  createdAt: string
  updatedAt: string
}

export interface Rating {
  _id: string
  fromUserId: string | UserSummary
  toUserId: string | UserSummary
  tripId: string | TripSummary
  rating: number
  comment?: string
  createdAt: string
}

export interface Notification {
  _id: string
  userId: string
  type: string
  title: string
  body: string
  data?: Record<string, unknown>
  isRead: boolean
  createdAt: string
}

export interface ChatRoom {
  _id: string
  tripId: string | TripSummary
  participants: Array<{
    userId: string | UserSummary
    joinedAt: string
  }>
  lastMessage?: string
  lastMessageTime?: string
  lastMessageSenderId?: string
  createdAt: string
  updatedAt: string
}

export interface ChatMessage {
  _id: string
  chatRoomId: string
  senderId: string
  senderName: string
  text: string
  createdAt: string
}

// View Models

export interface DashboardStats {
  totalUsers: number
  totalDrivers: number
  totalPassengers: number
  activeTrips: number
  completedTrips: number
  totalRevenue: number
  pendingPayments: number
  pendingManualTopups: number
  pendingVehicleVerifications: number
}

export interface ReportResponse {
  type: 'revenue' | 'users' | 'trips'
  period: {
    start: string
    end: string
  }
  summary: {
    total: number
    count: number
  }
  breakdown: Array<{
    date: string
    amount?: number
    count: number
  }>
}

export interface PaginatedResult<T> {
  data: T[]
  meta: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

// Summary Types

export interface UserSummary {
  _id: string
  name: string
  email: string
  phoneNumber?: string
}

export interface TripSummary {
  _id: string
  id?: string
  from?: Location | string
  to?: Location | string
  fromName?: string
  toName?: string
  departureTime: string
  /** Present on admin booking list so seat "row-col" can be shown as linear # */
  seatLayout?: SeatLayout
}

export interface BookingSummary {
  _id: string
  seatNumber: string
}

// User Stats (for user detail view)

export interface UserStats {
  totalTrips: number
  totalBookings: number
  totalPayments: number
  totalRatings: number
  averageRating: number
}

// Auth Types

export interface AuthUser {
  _id: string
  name: string
  email: string
  role: UserRole
  profileImageUrl?: string
}

export interface LoginResponse {
  accessToken: string
  refreshToken: string
  user: AuthUser
}

export interface RefreshResponse {
  accessToken: string
  refreshToken: string
}

// Wallet Types

export interface WalletAccount {
  id: string
  userId: string | UserSummary
  accountType: 'driver' | 'rider' | 'system'
  currency: string
  balance: string
  isActive: boolean
  createdAt: string
  updatedAt: string
}

export interface WalletTransaction {
  id: string
  accountId: string
  type: string
  direction: 'debit' | 'credit'
  status: string
  amount: number
  currency: string
  referenceType: string | null
  referenceId: string | null
  metadata: Record<string, unknown> | null
  createdAt: string
}

// Phase 3 — account safety flags
export type AccountFlagSeverity = 'low' | 'medium' | 'high' | 'critical'
export type AccountFlagDisposition = 'open' | 'resolved' | 'dismissed'

export interface AccountFlag {
  id: string
  userId: string | UserSummary
  reason: string           // e.g. 'multi_account_device' | 'mock_location_repeated'
  severity: AccountFlagSeverity
  disposition: AccountFlagDisposition
  metadata?: Record<string, unknown>
  resolvedBy?: string
  resolvedAt?: string
  createdAt: string
  updatedAt: string
}

// Phase 8 — complaints & refunds

export type ComplaintStatus = 'pending' | 'under_review' | 'resolved' | 'rejected'

export interface Complaint {
  id: string
  reporterId: string | UserSummary
  againstUserId?: string | UserSummary | null
  tripId?: string | null
  category: string          // SAFETY | PAYMENT | VEHICLE_CONDITION | DRIVER_BEHAVIOR | APP_ISSUE | OTHER
  description: string
  status: ComplaintStatus
  adminNotes?: string | null
  resolvedAt?: string | null
  createdAt: string
  updatedAt: string
}

export type RefundRequestStatus = 'pending' | 'approved' | 'rejected'

export interface RefundRequest {
  id: string
  userId: string | UserSummary
  bookingId: string | BookingSummary
  reason: string
  status: RefundRequestStatus
  adminNotes?: string | null
  whatsappContactedAt?: string | null
  resolvedAt?: string | null
  createdAt: string
  updatedAt: string
}
