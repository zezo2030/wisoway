// Payments API: Payment-related API functions
// T023: Implements pending queue, all payments, approve, and reject API calls

import type { Payment, PaginatedResult } from "@/types/models"
import type {
  ApiResponse,
  GetPendingPaymentsParams,
  GetAllPaymentsParams,
  ApprovePaymentRequest,
  RejectPaymentRequest,
} from "@/types/api"
import { apiClient } from "./client"

/**
 * Get pending payments queue
 */
export async function getPendingPayments(
  params: GetPendingPaymentsParams
): Promise<PaginatedResult<Payment>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Payment>>>(
    "/admin/payments/pending",
    { params }
  )
  return response.data.data
}

/**
 * Get all payments with filters
 */
export async function getAllPayments(
  params: GetAllPaymentsParams
): Promise<PaginatedResult<Payment>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<Payment>>>(
    "/admin/payments",
    { params }
  )
  return response.data.data
}

/**
 * Approve a pending payment
 */
export async function approvePayment(
  paymentId: string,
  adminNote?: string
): Promise<Payment> {
  const request: ApprovePaymentRequest = { adminNote }
  const response = await apiClient.patch<ApiResponse<Payment>>(
    `/payments/${paymentId}/approve`,
    request
  )
  return response.data.data
}

/**
 * Reject a pending payment
 */
export async function rejectPayment(
  paymentId: string,
  adminNote?: string
): Promise<Payment> {
  const request: RejectPaymentRequest = { adminNote }
  const response = await apiClient.patch<ApiResponse<Payment>>(
    `/payments/${paymentId}/reject`,
    request
  )
  return response.data.data
}
