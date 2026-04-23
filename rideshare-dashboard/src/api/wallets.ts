// Wallets API: Wallet account management API functions

import type { WalletAccount, WalletTransaction, PaginatedResult } from "@/types/models"
import type {
  ApiResponse,
  GetWalletsParams,
  PaginationParams,
  AdjustWalletBalanceRequest,
} from "@/types/api"
import { apiClient } from "./client"

/**
 * Get all wallet accounts with filters
 */
export async function getWallets(
  params: GetWalletsParams
): Promise<PaginatedResult<WalletAccount>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<WalletAccount>>>(
    "/admin/wallets",
    { params }
  )
  return response.data.data
}

/**
 * Get a single wallet account by ID
 */
export async function getWalletById(walletId: string): Promise<WalletAccount> {
  const response = await apiClient.get<ApiResponse<WalletAccount>>(
    `/admin/wallets/${walletId}`
  )
  return response.data.data
}

/**
 * Get transactions for a wallet account
 */
export async function getWalletTransactions(
  walletId: string,
  params: PaginationParams
): Promise<PaginatedResult<WalletTransaction>> {
  const response = await apiClient.get<ApiResponse<PaginatedResult<WalletTransaction>>>(
    `/admin/wallets/${walletId}/transactions`,
    { params }
  )
  return response.data.data
}

/**
 * Adjust wallet balance manually as admin.
 */
export async function adjustWalletBalance(
  walletId: string,
  data: AdjustWalletBalanceRequest
): Promise<WalletAccount> {
  const response = await apiClient.patch<ApiResponse<WalletAccount>>(
    `/admin/wallets/${walletId}/adjust`,
    data
  )
  return response.data.data
}
