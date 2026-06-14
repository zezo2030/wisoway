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
  SeatLayout,
  ReportResponse,
  Rating,
  Notification,
  ChatRoom,
  ChatMessage,
  AccountFlag,
  PendingCharge,
  SettlementAudit,
  Complaint,
  ComplaintStatus,
  RefundRequest,
  RefundRequestStatus,
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
import { backendSeatIdToDisplayIndex } from "@/lib/seat-layout"

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

type TripSeatLayoutPayload = Pick<SeatLayout, "rows" | "seatsPerRow" | "seatsPerRowList">

/** Map API seat id to linear 1-based index for SeatMap (uniform or mixed layout). */
function normalizeSeatNumberForLayout(raw: unknown, layout: TripSeatLayoutPayload): number {
  if (typeof raw === "number" && Number.isFinite(raw)) {
    return raw
  }
  const s = String(raw ?? "")
  const idx = backendSeatIdToDisplayIndex(layout, s)
  if (idx != null) return idx
  const n = Number(s)
  return Number.isFinite(n) ? n : 0
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
    const rawLayout = record.seatLayout as Record<string, unknown> | undefined
    const rows =
      typeof rawLayout?.rows === "number" && rawLayout.rows > 0 ? rawLayout.rows : 1
    const seatsPerRow =
      typeof rawLayout?.seatsPerRow === "number" && rawLayout.seatsPerRow > 0
        ? rawLayout.seatsPerRow
        : 4
    const seatsPerRowList = Array.isArray(rawLayout?.seatsPerRowList)
      ? (rawLayout.seatsPerRowList as unknown[]).map((x) => Number(x)).filter((n) => n > 0)
      : undefined
    const layout: TripSeatLayoutPayload = {
      rows,
      seatsPerRow,
      seatsPerRowList: seatsPerRowList && seatsPerRowList.length > 0 ? seatsPerRowList : undefined,
    }

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
          seatNumber: normalizeSeatNumberForLayout(seatRecord.seatNumber, layout),
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

function getObjectId(value: unknown): string | null {
  if (typeof value === "string" && value.length > 0) return value
  if (!value || typeof value !== "object") return null

  const obj = value as Record<string, unknown>
  if (typeof obj.id === "string" && obj.id.length > 0) return obj.id
  if (typeof obj._id === "string" && obj._id.length > 0) return obj._id
  return null
}

function getRoomTripId(room: unknown): string | null {
  if (!room || typeof room !== "object") return null
  const obj = room as Record<string, unknown>

  const directTripId = getObjectId(obj.tripId)
  if (directTripId) return directTripId

  const relationTripId = getObjectId(obj.trip)
  if (relationTripId) return relationTripId

  return null
}

/**
 * Get chat room for a specific trip.
 * Admin endpoint does not support tripId filtering, so scan paginated rooms and match client-side.
 */
export async function getChatRoomByTripId(tripId: string): Promise<ChatRoom | null> {
  const normalizedTripId = tripId.trim()
  if (!normalizedTripId) return null

  const limit = 100
  const maxPages = 25
  let page = 1
  let totalPages = 1

  while (page <= totalPages && page <= maxPages) {
    const roomsPage = await getChatRooms({ page, limit })
    const rooms = roomsPage.data ?? []

    const matched = rooms.find((room) => getRoomTripId(room) === normalizedTripId)
    if (matched) {
      return matched
    }

    totalPages = Math.max(roomsPage.meta?.totalPages ?? 1, 1)
    page += 1
  }

  return null
}

/**
 * Get messages for a chat room (legacy Mongo endpoint)
 */
export async function getChatMessages(roomId: string, params: GetChatMessagesParams): Promise<PaginatedResult<ChatMessage>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<ChatMessage>>>(`/admin/chat/rooms/${roomId}/messages`, {
    params,
  })
  return response.data.data
}

/**
 * Get all chat rooms for a specific trip (PG admin endpoint with tripId filter)
 */
export async function getChatRoomsForTrip(tripId: string): Promise<PaginatedResult<ChatRoom>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<ChatRoom>>>("/admin/chat/rooms", {
    params: { tripId, limit: 50, page: 1 },
  })
  return response.data.data
}

/**
 * Get messages for a chat room via PG admin endpoint
 */
export async function getDashboardChatMessages(roomId: string, params: GetChatMessagesParams): Promise<PaginatedResult<ChatMessage>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<ChatMessage>>>(`/admin/chat/rooms/${roomId}/messages`, {
    params,
  })
  return response.data.data
}

export interface TripTrackingPoint {
  id: string
  tripId: string
  driverId: string
  latitude: number
  longitude: number
  speedKph: number | null
  heading: number | null
  accuracyMeters: number | null
  recordedAt: string
}

/**
 * Get latest live location for a trip
 */
export async function getTripTrackingLatest(tripId: string): Promise<TripTrackingPoint | null> {
  const response = await apiClient.get<ApiResponse<TripTrackingPoint | null>>(`/tracking/${tripId}/latest`)
  return response.data.data
}

/**
 * Get location history for a trip
 */
export async function getTripTrackingHistory(tripId: string, limit = 200): Promise<TripTrackingPoint[]> {
  const response = await apiClient.get<ApiResponse<TripTrackingPoint[]>>(`/tracking/${tripId}/history`, {
    params: { limit },
  })
  return response.data.data
}

export interface PlatformPricingSettings {
  id: string
  countryCode: string
  feeAmount: number | string
  currency: string
  isActive: boolean
  passengerPlatformPercent: number | string
  driverUnlockPercent: number | string
  lifetimeFreeTripEnabled: boolean
}

export async function getPlatformPricingSettings(countryCode = "EG"): Promise<PlatformPricingSettings> {
  const response = await apiClient.get<ApiResponse<PlatformPricingSettings>>("/admin/pricing-settings", {
    params: { countryCode },
  })
  return response.data.data
}

export async function patchPlatformPricingSettings(
  countryCode: string,
  body: Partial<{
    feeAmount: number
    currency: string
    isActive: boolean
    passengerPlatformPercent: number
    driverUnlockPercent: number
    lifetimeFreeTripEnabled: boolean
  }>,
): Promise<PlatformPricingSettings> {
  const response = await apiClient.patch<ApiResponse<PlatformPricingSettings>>("/admin/pricing-settings", body, {
    params: { countryCode },
  })
  return response.data.data
}

// ─── Account Flags (Phase 3) ─────────────────────────────────────────────────

export interface GetAccountFlagsParams {
  page?: number
  limit?: number
  disposition?: 'open' | 'resolved' | 'dismissed'
  severity?: string
  userId?: string
}

export async function getAccountFlags(
  params: GetAccountFlagsParams = {},
): Promise<PaginatedResult<AccountFlag>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<AccountFlag>>>(
    "/admin/account-flags",
    { params },
  )
  return response.data.data
}

export async function resolveAccountFlag(flagId: string): Promise<AccountFlag> {
  const response = await apiClient.patch<ApiResponse<AccountFlag>>(
    `/admin/account-flags/${flagId}/resolve`,
  )
  return response.data.data
}

export async function dismissAccountFlag(flagId: string): Promise<AccountFlag> {
  const response = await apiClient.patch<ApiResponse<AccountFlag>>(
    `/admin/account-flags/${flagId}/dismiss`,
  )
  return response.data.data
}

// ─── Pending Charges (Phase 4) ────────────────────────────────────────────────

export interface GetPendingChargesParams {
  page?: number
  limit?: number
  status?: 'pending' | 'collected' | 'waived' | 'failed'
  userId?: string
}

export async function getPendingCharges(
  params: GetPendingChargesParams = {},
): Promise<PaginatedResult<PendingCharge>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<PendingCharge>>>(
    "/admin/pending-charges",
    { params },
  )
  return response.data.data
}

export async function waivePendingCharge(chargeId: string): Promise<PendingCharge> {
  const response = await apiClient.patch<ApiResponse<PendingCharge>>(
    `/admin/pending-charges/${chargeId}/waive`,
  )
  return response.data.data
}

// ─── Fines (driver penalties) ────────────────────────────────────────────────

export interface Fine {
  id: string
  userId: string
  kind: string
  amount: string
  status: "pending" | "applied" | "waived"
  reason: string | null
  tripId: string | null
  bookingId: string | null
  createdByAdminId: string | null
  waivedByAdminId: string | null
  waivedAt: string | null
  createdAt: string
  driver: { id: string; name: string | null; phone: string | null }
}

export interface GetFinesParams {
  status?: "pending" | "applied" | "waived"
  driverId?: string
  from?: string
  to?: string
  page?: number
  limit?: number
}

export interface CreateFinePayload {
  driverId: string
  amount: number
  reason: string
  tripId?: string
  bookingId?: string
}

export async function getFines(
  params: GetFinesParams = {},
): Promise<PaginatedResult<Fine>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Fine>>>(
    "/admin/fines",
    { params },
  )
  return response.data.data
}

export async function createFine(payload: CreateFinePayload): Promise<Fine> {
  const response = await apiClient.post<ApiResponse<Fine>>(
    "/admin/fines",
    payload,
  )
  return response.data.data
}

export async function waiveFine(fineId: string): Promise<Fine> {
  const response = await apiClient.patch<ApiResponse<Fine>>(
    `/admin/fines/${fineId}/waive`,
  )
  return response.data.data
}

// ─── No-Show Reports ─────────────────────────────────────────────────────────

export interface NoShowReport {
  tripId: string
  driverId: string
  driverName: string | null
  driverPhone: string | null
  fromName: string
  toName: string
  departureTime: string
  tripStatus: string
  confirmedPassengers: number
  reportedAbsenceCount: number
  confirmedPresenceCount: number
  majorityReached: boolean
  earliestReportAt: string | null
  latestReportAt: string | null
  reporterBookingIds: string[]
  fineIssued: boolean
  fineId: string | null
}

export interface GetNoShowReportsParams {
  page?: number
  limit?: number
  majorityOnly?: boolean
  unfinedOnly?: boolean
}

export interface NoShowReportDetail {
  summary: NoShowReport
  bookings: Array<{
    bookingId: string
    passengerId: string
    passengerName: string | null
    passengerPhone: string | null
    status: string
    reportedAbsentAt: string | null
    confirmedPresenceAt: string | null
  }>
}

export async function getNoShowReports(
  params: GetNoShowReportsParams = {},
): Promise<PaginatedResult<NoShowReport>> {
  const response = await apiClient.get<
    ApiResponse<PaginatedResult<NoShowReport>>
  >("/admin/no-show-reports", {
    params: {
      page: params.page,
      limit: params.limit,
      majorityOnly: params.majorityOnly ? "true" : undefined,
      unfinedOnly: params.unfinedOnly ? "true" : undefined,
    },
  })
  return response.data.data
}

export async function getNoShowReportDetail(
  tripId: string,
): Promise<NoShowReportDetail> {
  const response = await apiClient.get<ApiResponse<NoShowReportDetail>>(
    `/admin/no-show-reports/${tripId}`,
  )
  return response.data.data
}

// ─── Settlement (Phase 7) ─────────────────────────────────────────────────────

/**
 * Admin revert of a booking settlement.
 * POST /admin/bookings/:bookingId/admin-revert-settlement
 */
export async function adminRevertSettlement(
  bookingId: string,
  reason?: string,
): Promise<Booking> {
  const response = await apiClient.post<ApiResponse<Booking>>(
    `/admin/bookings/${bookingId}/admin-revert-settlement`,
    { reason },
  )
  return response.data.data
}

/**
 * Get settlement audit trail for a booking.
 * GET /admin/bookings/:bookingId/settlement-audits
 */
export async function getSettlementAudits(bookingId: string): Promise<SettlementAudit[]> {
  const response = await apiClient.get<ApiResponse<SettlementAudit[]>>(
    `/admin/bookings/${bookingId}/settlement-audits`,
  )
  return response.data.data
}

// ─── Ban (Phase 8) ────────────────────────────────────────────────────────────

export async function banUser(userId: string, banReason?: string): Promise<User> {
  const response = await apiClient.post<ApiResponse<User>>(
    `/admin/users/${userId}/ban`,
    { banReason },
  )
  return response.data.data
}

export async function unbanUser(userId: string): Promise<User> {
  const response = await apiClient.post<ApiResponse<User>>(
    `/admin/users/${userId}/unban`,
    {},
  )
  return response.data.data
}

// ─── User Devices (Phase 8) ───────────────────────────────────────────────────

export interface UserDevice {
  id: string
  userId: string
  deviceId: string
  platform: string
  deviceName?: string
  status: 'active' | 'revoked'
  revokedAt?: string
  revokeReason?: string
  lastSeenAt?: string
  createdAt: string
}

export async function getUserDevices(userId: string): Promise<UserDevice[]> {
  const response = await apiClient.get<ApiResponse<UserDevice[]>>(
    `/admin/users/${userId}/devices`,
  )
  return response.data.data
}

// ─── Complaints (Phase 8) ─────────────────────────────────────────────────────

export interface GetComplaintsParams {
  page?: number
  limit?: number
  status?: ComplaintStatus
  cursor?: string
}

export async function getComplaints(
  params: GetComplaintsParams = {},
): Promise<PaginatedResult<Complaint>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Complaint>>>(
    "/admin/complaints",
    { params },
  )
  return response.data.data
}

export async function updateComplaint(
  id: string,
  payload: { status: ComplaintStatus; adminNotes?: string },
): Promise<Complaint> {
  const response = await apiClient.patch<ApiResponse<Complaint>>(
    `/admin/complaints/${id}`,
    payload,
  )
  return response.data.data
}

// ─── Refund Requests (Phase 8) ────────────────────────────────────────────────

export interface GetRefundRequestsParams {
  page?: number
  limit?: number
  status?: RefundRequestStatus
}

export async function getRefundRequests(
  params: GetRefundRequestsParams = {},
): Promise<PaginatedResult<RefundRequest>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<RefundRequest>>>(
    "/admin/refund-requests",
    { params },
  )
  return response.data.data
}

export async function updateRefundRequest(
  id: string,
  payload: { status: RefundRequestStatus; adminNotes?: string },
): Promise<RefundRequest> {
  const response = await apiClient.patch<ApiResponse<RefundRequest>>(
    `/admin/refund-requests/${id}`,
    payload,
  )
  return response.data.data
}
