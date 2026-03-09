// Admin API: Admin-related API functions
// T014, T017, T027: Implements dashboard stats, user management, and vehicle API calls

import type {
  DashboardStats,
  User,
  PaginatedResult,
  UserStats,
  Trip,
  Vehicle,
  Booking,
  Seat,
  ReportResponse,
  Rating,
  Notification,
  ChatRoom,
  ChatMessage,
} from "@/types/models"
import type {
  ApiResponse,
  GetUsersParams,
  ChangeUserRoleRequest,
  GetTripsParams,
  GetVehiclesParams,
  GetReportParams,
  GetBookingsParams,
  GetRatingsParams,
  GetChatRoomsParams,
  GetChatMessagesParams,
  GetAdminNotificationsParams,
  BroadcastNotificationRequest,
} from "@/types/api"
import { apiClient } from "./client"

/**
 * Get dashboard statistics
 */
export async function getDashboardStats(): Promise<DashboardStats> {
  const response = await apiClient.get<ApiResponse<DashboardStats>>("/admin/dashboard/stats")
  return response.data.data
}

/**
 * Get paginated list of users with filters
 */
export async function getUsers(params: GetUsersParams): Promise<PaginatedResult<User>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<User>>>("/admin/users", {
    params,
  })
  return response.data.data
}

/**
 * Change a user's role
 */
export async function changeUserRole(
  userId: string,
  role: ChangeUserRoleRequest["role"]
): Promise<User> {
  const response = await apiClient.patch<ApiResponse<User>>(`/admin/users/${userId}/role`, {
    role,
  })
  return response.data.data
}

/**
 * Toggle user ban status (isActive: false = ban, true = unban)
 */
export async function toggleUserBan(userId: string, isActive: boolean): Promise<User> {
  const response = await apiClient.patch<ApiResponse<User>>(`/admin/users/${userId}/ban`, {
    isActive,
  })
  return response.data.data
}

/**
 * Confirm user account (activate + mark phone/email verified)
 */
export async function confirmUser(userId: string): Promise<User> {
  const response = await apiClient.patch<ApiResponse<User>>(`/admin/users/${userId}/confirm`)
  return response.data.data
}

/**
 * Delete user account
 */
export async function deleteUser(userId: string): Promise<void> {
  await apiClient.delete(`/admin/users/${userId}`)
}

/**
 * Get user by ID
 */
export async function getUserById(userId: string): Promise<User> {
  const response = await apiClient.get<ApiResponse<User>>(`/users/${userId}`)
  return response.data.data
}

/**
 * Get user statistics
 */
export async function getUserStats(userId: string): Promise<UserStats> {
  const response = await apiClient.get<ApiResponse<UserStats>>(`/users/${userId}/stats`)
  return response.data.data
}

/**
 * Get paginated list of trips with filters
 */
export async function getTrips(params: GetTripsParams): Promise<PaginatedResult<Trip>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Trip>>>("/admin/trips", {
    params,
  })
  return response.data.data
}

/**
 * Get paginated list of vehicles
 */
export async function getVehicles(params: GetVehiclesParams): Promise<PaginatedResult<Vehicle>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Vehicle>>>("/admin/vehicles", {
    params,
  })
  return response.data.data
}

/**
 * Verify or reject a vehicle
 * isVerified: true = verify, false = reject
 */
export async function verifyVehicle(vehicleId: string, isVerified: boolean): Promise<Vehicle> {
  const response = await apiClient.patch<ApiResponse<Vehicle>>(`/admin/vehicles/${vehicleId}/verify`, {
    isVerified,
  })
  return response.data.data
}

/**
 * Approve or reject driver account
 */
export async function approveDriver(userId: string, approved: boolean): Promise<User> {
  const response = await apiClient.patch<
    ApiResponse<{ message: string; user: User }> | { message: string; user: User }
  >(`/admin/users/${userId}/approve-driver`, { approved })

  const payload = response.data
  if ("success" in payload && "data" in payload) {
    return payload.data.user
  }

  return payload.user
}

/**
 * Get a driver's vehicle record
 */
export async function getDriverVehicle(driverId: string): Promise<Vehicle | null> {
  const vehicles = await getVehicles({ page: 1, limit: 1, driverId })
  return vehicles.data[0] ?? null
}

/**
 * Get trip by ID
 */
export async function getTripById(tripId: string): Promise<Trip> {
  const response = await apiClient.get<ApiResponse<Trip>>(`/trips/${tripId}`)
  return response.data.data
}

/**
 * Get trip seats
 */
export async function getTripSeats(tripId: string): Promise<Seat[]> {
  const response = await apiClient.get<ApiResponse<unknown>>(`/trips/${tripId}/seats`)
  const payload = response.data.data

  if (Array.isArray(payload)) {
    return payload as Seat[]
  }

  if (payload && typeof payload === "object") {
    const record = payload as Record<string, unknown>
    const rawSeats = record.seats
    if (Array.isArray(rawSeats)) {
      return rawSeats.map((rawSeat) => {
        const seatRecord = (rawSeat ?? {}) as Record<string, unknown>
        const passengerGenderSource =
          typeof seatRecord.passengerGender === "string"
            ? seatRecord.passengerGender
            : typeof seatRecord.gender === "string"
              ? seatRecord.gender
              : undefined

        return {
          seatNumber: Number(seatRecord.seatNumber ?? 0),
          status: String(seatRecord.status ?? "available") as Seat["status"],
          passengerId:
            typeof seatRecord.passengerId === "string" ? seatRecord.passengerId : undefined,
          passengerGender:
            passengerGenderSource === "male" || passengerGenderSource === "female"
              ? passengerGenderSource
              : undefined,
        }
      })
    }
  }

  return []
}

/**
 * Get bookings for a trip
 */
export async function getBookingsForTrip(tripId: string): Promise<PaginatedResult<Booking>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Booking>>>("/admin/bookings", {
    params: { tripId, page: 1, limit: 100 },
  })
  return response.data.data
}

/**
 * Get report data
 */
export async function getReport(params: GetReportParams): Promise<ReportResponse> {
  const response = await apiClient.get<ApiResponse<ReportResponse>>("/admin/reports", {
    params,
  })
  return response.data.data
}

// ============= BOOKINGS MANAGEMENT =============

/**
 * Get paginated list of bookings with filters
 */
export async function getBookings(params: GetBookingsParams): Promise<PaginatedResult<Booking>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Booking>>>("/admin/bookings", {
    params,
  })
  return response.data.data
}

/**
 * Cancel a booking as admin
 */
export async function cancelBooking(bookingId: string): Promise<Booking> {
  const response = await apiClient.patch<ApiResponse<Booking>>(`/admin/bookings/${bookingId}/cancel`)
  return response.data.data
}

// ============= RATINGS MANAGEMENT =============

/**
 * Get paginated list of ratings with filters
 */
export async function getRatings(params: GetRatingsParams): Promise<PaginatedResult<Rating>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Rating>>>("/admin/ratings", {
    params,
  })
  return response.data.data
}

/**
 * Delete a rating
 */
export async function deleteRating(ratingId: string): Promise<void> {
  await apiClient.delete(`/admin/ratings/${ratingId}`)
}

// ============= NOTIFICATIONS MANAGEMENT =============

/**
 * Get all notifications (admin view)
 */
export async function getAdminNotifications(params: GetAdminNotificationsParams): Promise<PaginatedResult<Notification>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Notification>>>("/admin/notifications", {
    params,
  })
  return response.data.data
}

/**
 * Broadcast notification to users
 */
export async function broadcastNotification(data: BroadcastNotificationRequest): Promise<{ sent: number }> {
  const response = await apiClient.post<ApiResponse<{ sent: number }>>("/admin/notifications/broadcast", data)
  return response.data.data
}

// ============= CHAT MONITORING =============

/**
 * Get all chat rooms
 */
export async function getChatRooms(params: GetChatRoomsParams): Promise<PaginatedResult<ChatRoom>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<ChatRoom>>>("/admin/chat/rooms", {
    params,
  })
  return response.data.data
}

/**
 * Get messages for a chat room
 */
export async function getChatMessages(roomId: string, params: GetChatMessagesParams): Promise<PaginatedResult<ChatMessage>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<ChatMessage>>>(`/admin/chat/rooms/${roomId}/messages`, {
    params,
  })
  return response.data.data
}
