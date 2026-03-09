// Auth API: Authentication-related API functions
// T007: Implements login, refresh, and logout API calls

import type {
  LoginRequest,
  LoginResponseData,
  RefreshRequest,
  RefreshResponseData,
  LogoutResponse,
} from "@/types/api"
import { apiClient, setAccessToken, setRefreshToken, clearTokens, getAccessToken } from "./client"

/**
 * Login with email and password
 */
export async function login(credentials: LoginRequest): Promise<LoginResponseData> {
  const response = await apiClient.post("/auth/login", credentials)
  const { accessToken, refreshToken, user } = response.data.data

  // Store tokens in memory
  setAccessToken(accessToken)
  setRefreshToken(refreshToken)

  return { accessToken, refreshToken, user }
}

/**
 * Refresh access token using refresh token
 */
export async function refresh(refreshToken: string): Promise<RefreshResponseData> {
  const request: RefreshRequest = { refreshToken }
  const response = await apiClient.post("/auth/refresh", request)
  const { accessToken, refreshToken: newRefreshToken } = response.data.data

  // Update stored tokens
  setAccessToken(accessToken)
  setRefreshToken(newRefreshToken)

  return { accessToken, refreshToken: newRefreshToken }
}

/**
 * Logout current user
 */
export async function logout(): Promise<LogoutResponse> {
  try {
    const response = await apiClient.post("/auth/logout")
    clearTokens()
    return response.data.data
  } catch (error) {
    // Clear tokens even if API call fails
    clearTokens()
    throw error
  }
}

/**
 * Check if user is authenticated (has access token)
 */
export function isAuthenticated(): boolean {
  return !!getAccessToken()
}

// Re-export token functions for convenience
export {
  setAccessToken,
  setRefreshToken,
  getAccessToken,
  getRefreshToken,
  clearTokens,
} from "./client"
