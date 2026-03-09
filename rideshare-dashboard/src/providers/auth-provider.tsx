// Auth Provider: React Context for authentication state
// T008: Manages auth state, login/logout, and admin role verification

import type { AuthUser } from "@/types/models"
import type { LoginRequest } from "@/types/api"
import { login as apiLogin, logout as apiLogout, getAccessToken, getRefreshToken, clearTokens } from "@/api/auth"
import { apiClient } from "@/api/client"
import { UserRole } from "@/types/enums"
import axios from "axios"
import React, { createContext, useContext, useState, useCallback, useEffect } from "react"

interface AuthState {
  user: AuthUser | null
  accessToken: string | null
  refreshToken: string | null
  isAuthenticated: boolean
  isLoading: boolean
}

interface AuthContextType extends AuthState {
  login: (credentials: LoginRequest) => Promise<void>
  logout: () => Promise<void>
  error: string | null
  clearError: () => void
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

interface AuthProviderProps {
  children: React.ReactNode
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Check for existing tokens on mount and restore session
  useEffect(() => {
    const token = getAccessToken()
    if (!token) {
      setIsLoading(false)
      return
    }

    // Token exists in sessionStorage, try to restore the user session
    apiClient
      .get("/users/me")
      .then((response) => {
        const userData = response.data.data ?? response.data
        if (userData && userData.role === UserRole.ADMIN) {
          setUser(userData)
        } else {
          // Not an admin, clear tokens
          clearTokens()
        }
      })
      .catch(async (error) => {
        // On 401, interceptor may already try refresh.
        // If session restore still fails, attempt one explicit refresh+retry.
        if (axios.isAxiosError(error) && error.response?.status === 401) {
          const refreshToken = getRefreshToken()
          if (!refreshToken) {
            clearTokens()
            return
          }

          try {
            await apiClient.post("/auth/refresh", { refreshToken })
            const retryResponse = await apiClient.get("/users/me")
            const retryUserData = retryResponse.data.data ?? retryResponse.data

            if (retryUserData && retryUserData.role === UserRole.ADMIN) {
              setUser(retryUserData)
              return
            }
          } catch {
            clearTokens()
            return
          }
        }

        // If backend/network fails temporarily, keep tokens and let user retry.
      })
      .finally(() => {
        setIsLoading(false)
      })
  }, [])

  const login = useCallback(async (credentials: LoginRequest) => {
    setIsLoading(true)
    setError(null)

    try {
      const response = await apiLogin(credentials)

      // Check if user has admin role
      if (response.user.role !== UserRole.ADMIN) {
        setError("Admin access required")
        setIsLoading(false)
        throw new Error("Admin access required")
      }

      setUser(response.user)
      setIsLoading(false)
    } catch (err) {
      setIsLoading(false)
      if (err instanceof Error) {
        if (err.message.includes("401") || err.message.includes("Invalid credentials")) {
          setError("Invalid credentials")
        } else if (!error) {
          setError(err.message || "Login failed")
        }
      } else {
        setError("Login failed")
      }
      throw err
    }
  }, [error])

  const logout = useCallback(async () => {
    setIsLoading(true)
    try {
      await apiLogout()
    } finally {
      setUser(null)
      setError(null)
      setIsLoading(false)
    }
  }, [])

  const clearError = useCallback(() => {
    setError(null)
  }, [])

  const value: AuthContextType = {
    user,
    accessToken: getAccessToken(),
    refreshToken: getRefreshToken(),
    isAuthenticated: !!user,
    isLoading,
    login,
    logout,
    error,
    clearError,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextType {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider")
  }
  return context
}
