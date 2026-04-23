// API Types: Rideshare Admin Dashboard
// Source: api-contracts.md

import type { PaginatedResult, User, Trip, Payment, Vehicle, Notification, DashboardStats, ReportResponse, UserStats, AuthUser, Booking, Rating, ChatRoom, ChatMessage, WalletAccount, WalletTransaction } from './models';
import type { UserRole, PaymentStatus, PaymentMethod, PaymentType, TripStatus, BookingStatus, WalletAccountType } from './enums';

// Generic API Response Wrapper

export interface ApiResponse<T> {
  success: true;
  data: T;
}

// Pagination

export interface PaginationParams {
  page?: number;
  limit?: number;
}

// Auth API Types

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponseData {
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface RefreshResponseData {
  accessToken: string;
  refreshToken: string;
}

export interface LogoutResponse {
  message: string;
}

// Admin API Types

export interface GetUsersParams extends PaginationParams {
  role?: UserRole;
  search?: string;
  isActive?: boolean;
}

export interface ChangeUserRoleRequest {
  role: UserRole;
}

export interface ToggleUserBanRequest {
  isActive: boolean;
}

export interface GetTripsParams extends PaginationParams {
  status?: TripStatus;
  driverId?: string;
}

export interface GetPendingPaymentsParams extends PaginationParams { }

export interface GetAllPaymentsParams extends PaginationParams {
  status?: PaymentStatus;
  method?: PaymentMethod;
  paymentType?: PaymentType;
  walletOnly?: boolean;
}

export interface ApprovePaymentRequest {
  adminNote?: string;
}

export interface RejectPaymentRequest {
  adminNote?: string;
}

export interface VerifyVehicleRequest {
  isVerified: boolean;
}

export interface GetVehiclesParams extends PaginationParams {
  isVerified?: boolean;
  driverId?: string;
}

export interface GetReportParams {
  type: 'revenue' | 'users' | 'trips';
  startDate: string;
  endDate: string;
}

// Booking API Types

export interface GetBookingsParams extends PaginationParams {
  status?: BookingStatus;
  userId?: string;
  tripId?: string;
}

// Rating API Types

export interface GetRatingsParams extends PaginationParams {
  userId?: string;
  tripId?: string;
  minRating?: number;
}

// Chat API Types

export interface GetChatRoomsParams extends PaginationParams { }

export interface GetChatMessagesParams extends PaginationParams { }

// Broadcast Notification Types

export interface BroadcastNotificationRequest {
  title: string;
  body: string;
  targetRole?: UserRole;
}

export interface GetAdminNotificationsParams extends PaginationParams {
  type?: string;
}

// Notification API Types

export interface GetNotificationsParams extends PaginationParams { }

export interface UnreadCountResponse {
  count: number;
}

export interface MarkAllAsReadResponse {
  modifiedCount: number;
}

// Response Types

export type UsersResponse = ApiResponse<PaginatedResult<User>>;
export type UserResponse = ApiResponse<User>;
export type UserStatsResponse = ApiResponse<UserStats>;
export type DashboardStatsResponse = ApiResponse<DashboardStats>;
export type TripsResponse = ApiResponse<PaginatedResult<Trip>>;
export type TripResponse = ApiResponse<Trip>;
export type PendingPaymentsResponse = ApiResponse<PaginatedResult<Payment>>;
export type AllPaymentsResponse = ApiResponse<PaginatedResult<Payment>>;
export type PaymentResponse = ApiResponse<Payment>;
export type VehiclesResponse = ApiResponse<PaginatedResult<Vehicle>>;
export type VehicleResponse = ApiResponse<Vehicle>;
export type ReportResponseData = ApiResponse<ReportResponse>;
export type NotificationsResponse = ApiResponse<PaginatedResult<Notification>>;
export type NotificationResponse = ApiResponse<Notification>;
export type UnreadCountApiResponse = ApiResponse<UnreadCountResponse>;
export type MarkAllAsReadApiResponse = ApiResponse<MarkAllAsReadResponse>;
export type BookingsResponse = ApiResponse<PaginatedResult<Booking>>;
export type BookingResponse = ApiResponse<Booking>;
export type RatingsResponse = ApiResponse<PaginatedResult<Rating>>;
export type ChatRoomsResponse = ApiResponse<PaginatedResult<ChatRoom>>;
export type ChatMessagesResponse = ApiResponse<PaginatedResult<ChatMessage>>;
export type BroadcastResponse = ApiResponse<{ sent: number }>;

// Auth Response Types

export type LoginApiResponse = ApiResponse<LoginResponseData>;
export type RefreshApiResponse = ApiResponse<RefreshResponseData>;
export type LogoutApiResponse = ApiResponse<LogoutResponse>;

// Wallet API Types

export interface GetWalletsParams extends PaginationParams {
  accountType?: WalletAccountType;
  search?: string;
  minBalance?: number;
  maxBalance?: number;
  isActive?: boolean;
}

export type WalletsResponse = ApiResponse<PaginatedResult<WalletAccount>>;
export type WalletResponse = ApiResponse<WalletAccount>;
export type WalletTransactionsResponse = ApiResponse<PaginatedResult<WalletTransaction>>;
