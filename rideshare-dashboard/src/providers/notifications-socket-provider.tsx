// Establishes the admin's Socket.IO connection to the /notifications namespace
// and pushes incoming notifications into react-query + toast.

import { useEffect, useRef } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { io, Socket } from "socket.io-client"
import { toast } from "sonner"
import { useAuth } from "@/providers/auth-provider"
import { useLanguage } from "@/providers/language-provider"
import { getAccessToken } from "@/api/client"
import { QUERY_KEYS, WS_URL } from "@/lib/constants"
import type { Notification } from "@/types/models"

interface NotificationsSocketProviderProps {
  children: React.ReactNode
}

export function NotificationsSocketProvider({
  children,
}: NotificationsSocketProviderProps) {
  const { isAuthenticated, user } = useAuth()
  const { t } = useLanguage()
  const queryClient = useQueryClient()
  const socketRef = useRef<Socket | null>(null)

  useEffect(() => {
    if (!isAuthenticated || !user?._id) return

    const token = getAccessToken()
    if (!token) return

    const socket = io(`${WS_URL}/notifications`, {
      transports: ["websocket"],
      auth: { token },
      query: { token },
      reconnection: true,
    })
    socketRef.current = socket

    socket.on("connect", () => {
      socket.emit("subscribe")
    })

    socket.on("newNotification", (payload: Notification) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.NOTIFICATIONS.LIST] })
      queryClient.invalidateQueries({
        queryKey: [QUERY_KEYS.NOTIFICATIONS.UNREAD_COUNT],
      })
      queryClient.invalidateQueries({
        queryKey: [QUERY_KEYS.ADMIN.NOTIFICATIONS],
      })
      if (payload?.type === "new_user_registered") {
        queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      }

      const title =
        payload?.title ||
        (payload?.type === "new_user_registered"
          ? t("newUserRegistered")
          : t("notifications"))
      toast(title, {
        description: payload?.body ?? undefined,
      })
    })

    socket.on("connect_error", () => {
      // Silent — reconnect logic handles it.
    })

    return () => {
      socket.off("newNotification")
      socket.disconnect()
      socketRef.current = null
    }
  }, [isAuthenticated, user?._id, queryClient, t])

  return <>{children}</>
}
