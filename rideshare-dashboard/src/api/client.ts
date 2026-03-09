// API Client: Axios instance with JWT interceptors
// T006: Implements request/response interceptors for token management

import axios, { type AxiosInstance, type AxiosError, type InternalAxiosRequestConfig } from "axios"
import { API_BASE_URL } from "@/lib/constants"

// Token storage (sessionStorage to survive page refreshes within the same tab)
const TOKEN_KEYS = {
  ACCESS: "rideshare_access_token",
  REFRESH: "rideshare_refresh_token",
} as const

// Token getter/setter functions
export function setAccessToken(token: string | null) {
  if (token) {
    sessionStorage.setItem(TOKEN_KEYS.ACCESS, token)
  } else {
    sessionStorage.removeItem(TOKEN_KEYS.ACCESS)
  }
}

export function setRefreshToken(token: string | null) {
  if (token) {
    sessionStorage.setItem(TOKEN_KEYS.REFRESH, token)
  } else {
    sessionStorage.removeItem(TOKEN_KEYS.REFRESH)
  }
}

export function getAccessToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEYS.ACCESS)
}

export function getRefreshToken(): string | null {
  return sessionStorage.getItem(TOKEN_KEYS.REFRESH)
}

export function clearTokens() {
  sessionStorage.removeItem(TOKEN_KEYS.ACCESS)
  sessionStorage.removeItem(TOKEN_KEYS.REFRESH)
}

// Create axios instance
export const apiClient: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    "Content-Type": "application/json",
  },
})

// Track if we're currently refreshing to prevent multiple refresh calls
let isRefreshing = false
let refreshSubscribers: Array<(token: string) => void> = []

function subscribeTokenRefresh(callback: (token: string) => void) {
  refreshSubscribers.push(callback)
}

function onTokenRefreshed(newToken: string) {
  refreshSubscribers.forEach((callback) => callback(newToken))
  refreshSubscribers = []
}

// Request interceptor: Attach Bearer token
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = getAccessToken()
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor: Handle 401 and token refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean }

    // If error is not 401 or request already retried, reject immediately
    if (error.response?.status !== 401 || originalRequest._retry) {
      return Promise.reject(error)
    }

    // Don't try to refresh for auth endpoints (prevents loops)
    const requestUrl = originalRequest.url || ""
    if (requestUrl.includes("/auth/login") || requestUrl.includes("/auth/refresh")) {
      return Promise.reject(error)
    }

    // If no refresh token, clear tokens and redirect (only if not already on login)
    const currentRefreshToken = getRefreshToken()
    if (!currentRefreshToken) {
      clearTokens()
      if (!window.location.pathname.includes("/login")) {
        window.location.href = "/login"
      }
      return Promise.reject(error)
    }

    // If already refreshing, queue the request
    if (isRefreshing) {
      return new Promise((resolve, reject) => {
        subscribeTokenRefresh((newToken: string) => {
          if (newToken) {
            if (originalRequest.headers) {
              originalRequest.headers.Authorization = `Bearer ${newToken}`
            }
            resolve(apiClient(originalRequest))
          } else {
            reject(error)
          }
        })
      })
    }

    // Attempt token refresh
    originalRequest._retry = true
    isRefreshing = true

    try {
      const response = await axios.post(`${API_BASE_URL}/auth/refresh`, {
        refreshToken: currentRefreshToken,
      })

      const { accessToken: newAccessToken, refreshToken: newRefreshToken } = response.data.data

      setAccessToken(newAccessToken)
      setRefreshToken(newRefreshToken)
      onTokenRefreshed(newAccessToken)

      // Retry original request with new token
      if (originalRequest.headers) {
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`
      }
      return apiClient(originalRequest)
    } catch (refreshError) {
      // Refresh failed, clear tokens and redirect (only if not already on login)
      clearTokens()
      if (!window.location.pathname.includes("/login")) {
        window.location.href = "/login"
      }
      return Promise.reject(refreshError)
    } finally {
      isRefreshing = false
    }
  }
)

export default apiClient
