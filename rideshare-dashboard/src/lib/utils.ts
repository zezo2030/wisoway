import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"
import { format, formatDistanceToNow } from "date-fns"
import {
  UserRole,
  TripStatus,
  BookingStatus,
  PaymentStatus,
  PaymentMethod,
  PaymentType,
  SeatStatus,
  Currency,
  Gender,
} from "@/types/enums"

// Tailwind class merger
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Date formatters
export function formatDate(date: string | Date): string {
  return format(new Date(date), "MMM d, yyyy")
}

export function formatDateTime(date: string | Date): string {
  return format(new Date(date), "MMM d, yyyy h:mm a")
}

export function formatTime(date: string | Date): string {
  return format(new Date(date), "h:mm a")
}

export function formatRelativeTime(date: string | Date): string {
  return formatDistanceToNow(new Date(date), { addSuffix: true })
}

// Currency formatter
export function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: currency,
  }).format(amount)
}

// Number formatter
export function formatNumber(num: number): string {
  return new Intl.NumberFormat("en-US").format(num)
}

// Status label mappers
export function getUserRoleLabel(role: UserRole): string {
  const labels: Record<UserRole, string> = {
    [UserRole.PASSENGER]: "Passenger",
    [UserRole.DRIVER]: "Driver",
    [UserRole.ADMIN]: "Admin",
  }
  return labels[role] || role
}

export function getTripStatusLabel(status: TripStatus): string {
  const labels: Record<TripStatus, string> = {
    [TripStatus.ACTIVE]: "Active",
    [TripStatus.HIDDEN]: "Hidden",
    [TripStatus.COMPLETED]: "Completed",
    [TripStatus.CANCELLED]: "Cancelled",
    [TripStatus.EXPIRED]: "Expired",
  }
  return labels[status] || status
}

export function getBookingStatusLabel(status: BookingStatus): string {
  const labels: Record<BookingStatus, string> = {
    [BookingStatus.PENDING]: "Pending",
    [BookingStatus.CONFIRMED]: "Confirmed",
    [BookingStatus.CANCELLED]: "Cancelled",
    [BookingStatus.COMPLETED]: "Completed",
  }
  return labels[status] || status
}

export function getPaymentStatusLabel(status: PaymentStatus): string {
  const labels: Record<PaymentStatus, string> = {
    [PaymentStatus.PENDING]: "Pending",
    [PaymentStatus.APPROVED]: "Approved",
    [PaymentStatus.REJECTED]: "Rejected",
    [PaymentStatus.REFUNDED]: "Refunded",
  }
  return labels[status] || status
}

export function getPaymentMethodLabel(method: PaymentMethod): string {
  const labels: Record<PaymentMethod, string> = {
    [PaymentMethod.STRIPE]: "Stripe",
    [PaymentMethod.PAYMOB]: "Paymob",
    [PaymentMethod.MANUAL]: "Manual",
    [PaymentMethod.COMMUNICATION_FEE]: "Communication Fee",
  }
  return labels[method] || method
}

export function getPaymentTypeLabel(type: PaymentType): string {
  const labels: Record<PaymentType, string> = {
    [PaymentType.TRIP]: "Trip",
    [PaymentType.COMMUNICATION_FEE]: "Communication Fee",
    [PaymentType.WALLET_TOPUP]: "Wallet Top-up",
    [PaymentType.WALLET_TRIP_CHARGE]: "Wallet Trip Charge",
  }
  return labels[type] || type
}

export function getSeatStatusLabel(status: SeatStatus): string {
  const labels: Record<SeatStatus, string> = {
    [SeatStatus.AVAILABLE]: "Available",
    [SeatStatus.BOOKED]: "Booked",
    [SeatStatus.LOCKED]: "Locked",
  }
  return labels[status] || status
}

export function getCurrencyLabel(currency: Currency): string {
  const labels: Record<Currency, string> = {
    [Currency.EGP]: "Egyptian Pound",
    [Currency.JOD]: "Jordanian Dinar",
    [Currency.SAR]: "Saudi Riyal",
    [Currency.AED]: "UAE Dirham",
    [Currency.QAR]: "Qatari Riyal",
  }
  return labels[currency] || currency
}

export function getGenderLabel(gender: Gender): string {
  const labels: Record<Gender, string> = {
    [Gender.MALE]: "Male",
    [Gender.FEMALE]: "Female",
  }
  return labels[gender] || gender
}
