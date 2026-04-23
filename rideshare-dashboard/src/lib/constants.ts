// Constants: Rideshare Admin Dashboard

// Route Paths
export const ROUTES = {
  // Public
  LOGIN: "/login",

  // Protected
  DASHBOARD: "/dashboard",
  USERS: "/users",
  USER_DETAIL: "/users/:id",
  PAYMENTS: "/payments",
  PAYMENTS_PENDING: "/payments/pending",
  WALLETS: "/wallets",
  WALLET_DETAIL: "/wallets/:id",
  VEHICLES: "/vehicles",
  TRIPS: "/trips",
  TRIP_DETAIL: "/trips/:id",
  BOOKINGS: "/bookings",
  RATINGS: "/ratings",
  NOTIFICATIONS: "/notifications",
  CHAT: "/chat",
  REPORTS: "/reports",
  PRICING_SETTINGS: "/settings/pricing",
} as const

// Navigation Items (for sidebar)
export const NAV_ITEMS = [
  { path: ROUTES.DASHBOARD, label: "Dashboard", icon: "LayoutDashboard" },
  { path: ROUTES.USERS, label: "Users", icon: "Users" },
  { path: ROUTES.PAYMENTS, label: "Payments", icon: "CreditCard" },
  { path: ROUTES.WALLETS, label: "Wallets", icon: "Wallet" },
  { path: ROUTES.VEHICLES, label: "Vehicles", icon: "Car" },
  { path: ROUTES.TRIPS, label: "Trips", icon: "MapPin" },
  { path: ROUTES.BOOKINGS, label: "Bookings", icon: "BookOpen" },
  { path: ROUTES.RATINGS, label: "Ratings", icon: "Star" },
  { path: ROUTES.NOTIFICATIONS, label: "Notifications", icon: "Bell" },
  { path: ROUTES.CHAT, label: "Chat", icon: "MessageSquare" },
  { path: ROUTES.REPORTS, label: "Reports", icon: "BarChart3" },
  { path: ROUTES.PRICING_SETTINGS, label: "Pricing", icon: "Percent" },
] as const

// Page Sizes for Pagination
export const PAGE_SIZES = [10, 20, 50] as const
export const DEFAULT_PAGE_SIZE = 20

// Enum Display Labels
export const USER_ROLE_LABELS = {
  passenger: "Passenger",
  driver: "Driver",
  admin: "Admin",
} as const

export const TRIP_STATUS_LABELS = {
  active: "Active",
  hidden: "Hidden",
  completed: "Completed",
  cancelled: "Cancelled",
  expired: "Expired",
} as const

export const BOOKING_STATUS_LABELS = {
  pending: "Pending",
  confirmed: "Confirmed",
  cancelled: "Cancelled",
  completed: "Completed",
} as const

export const PAYMENT_STATUS_LABELS = {
  pending: "Pending",
  approved: "Approved",
  rejected: "Rejected",
  refunded: "Refunded",
} as const

export const PAYMENT_METHOD_LABELS = {
  wallet: "Wallet",
  paymob: "Paymob",
  manual: "Manual",
  communication_fee: "Communication Fee",
} as const

export const PAYMENT_TYPE_LABELS = {
  trip: "Trip",
  trip_platform: "Trip (platform fee)",
  communication_fee: "Communication Fee",
} as const

export const SEAT_STATUS_LABELS = {
  available: "Available",
  booked: "Booked",
  locked: "Locked",
} as const

export const CURRENCY_LABELS = {
  EGP: "EGP",
  JOD: "JOD",
  SAR: "SAR",
  AED: "AED",
  QAR: "QAR",
} as const

export const GENDER_LABELS = {
  male: "Male",
  female: "Female",
} as const

// Status Badge Variants (for shadcn/ui Badge component)
export const STATUS_VARIANTS = {
  // User status
  active: "default",
  banned: "destructive",

  // Payment status
  pending: "secondary",
  approved: "default",
  rejected: "destructive",
  refunded: "outline",

  // Trip status
  active_trip: "default",
  hidden: "secondary",
  completed: "default",
  cancelled: "destructive",
  expired: "outline",

  // Booking status
  pending_booking: "secondary",
  confirmed: "default",
  cancelled_booking: "destructive",
  completed_booking: "default",

  // Vehicle status
  verified: "default",
  unverified: "secondary",
} as const

// API Config
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:3000/api/v1"
export const WS_URL = import.meta.env.VITE_WS_URL || "http://localhost:3000"

// Query Keys for TanStack Query
export const QUERY_KEYS = {
  AUTH: {
    USER: "auth-user",
  },
  ADMIN: {
    DASHBOARD_STATS: "dashboard-stats",
    USERS: "users",
    USER: "user",
    USER_STATS: "user-stats",
    TRIPS: "trips",
    TRIP: "trip",
    VEHICLES: "vehicles",
    BOOKINGS: "bookings",
    RATINGS: "ratings",
    NOTIFICATIONS: "admin-notifications",
    CHAT_ROOMS: "chat-rooms",
    CHAT_MESSAGES: "chat-messages",
    REPORTS: "reports",
  },
  PAYMENTS: {
    PENDING: "payments-pending",
    ALL: "payments-all",
  },
  WALLETS: {
    ALL: "wallets-all",
    DETAIL: "wallet-detail",
    TRANSACTIONS: "wallet-transactions",
  },
  NOTIFICATIONS: {
    LIST: "notifications",
    UNREAD_COUNT: "notifications-unread-count",
  },
} as const

// Dashboard Stats Refresh Interval (30 seconds)
export const DASHBOARD_REFRESH_INTERVAL = 30000

// Default Date Range for Reports (30 days)
export const DEFAULT_REPORT_DAYS = 30

// Toast Duration (milliseconds)
export const TOAST_DURATION = 5000
