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
  createdAt: string
  updatedAt: string
}

export interface Booking {
  _id: string
  userId: string | UserSummary
  tripId: string | TripSummary
  seatNumber: string
  status: BookingStatus
  hasDriverPaidToContact: boolean
  sharePhoneWithDriver: boolean
  cancellationReason?: string
  cancelledAt?: string
  cancelledBy?: 'passenger' | 'driver' | 'system'
  createdAt: string
  updatedAt: string
}

export interface Payment {
  _id: string
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
