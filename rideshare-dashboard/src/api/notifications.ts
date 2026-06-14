// User-scoped notifications API (for the signed-in admin's personal inbox).
// Backed by /notifications (NotificationsController), not /admin/notifications.

import type { Notification, PaginatedResult } from "@/types/models"
import type { ApiResponse, PaginationParams } from "@/types/api"
import { apiClient } from "./client"

export interface GetMyNotificationsParams extends PaginationParams {
  isRead?: boolean
}

export async function getMyNotifications(
  params: GetMyNotificationsParams,
): Promise<PaginatedResult<Notification>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Notification>>>(
    "/notifications",
    { params },
  )
  return response.data.data
}

export async function getMyUnreadCount(): Promise<number> {
  const response = await apiClient.get<
    ApiResponse<{ count: number } | { success: true; data: { count: number } }>
  >("/notifications/unread-count")
  const payload = response.data.data as
    | { count: number }
    | { data: { count: number } }
  if (payload && typeof (payload as { count: number }).count === "number") {
    return (payload as { count: number }).count
  }
  return (payload as { data: { count: number } }).data?.count ?? 0
}

export async function markNotificationRead(
  notificationId: string,
): Promise<Notification> {
  const response = await apiClient.patch<
    ApiResponse<Notification | { success: true; data: Notification }>
  >(`/notifications/${notificationId}/read`)
  const payload = response.data.data as
    | Notification
    | { data: Notification }
  return ((payload as { data?: Notification }).data ??
    (payload as Notification)) as Notification
}

export async function markAllNotificationsRead(): Promise<{
  updatedCount: number
}> {
  const response = await apiClient.patch<
    ApiResponse<
      | { updatedCount: number; message: string }
      | { success: true; data: { updatedCount: number; message: string } }
    >
  >("/notifications/read-all")
  const payload = response.data.data as
    | { updatedCount: number }
    | { data: { updatedCount: number } }
  if (payload && "updatedCount" in payload) {
    return { updatedCount: (payload as { updatedCount: number }).updatedCount }
  }
  return {
    updatedCount:
      (payload as { data: { updatedCount: number } }).data?.updatedCount ?? 0,
  }
}
