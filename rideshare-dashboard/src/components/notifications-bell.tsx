import { useState } from "react"
import { useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { Bell, CheckCheck, UserPlus, Megaphone, Inbox } from "lucide-react"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { useLanguage } from "@/providers/language-provider"
import { QUERY_KEYS, ROUTES } from "@/lib/constants"
import { cn, formatDate } from "@/lib/utils"
import {
  getMyNotifications,
  getMyUnreadCount,
  markAllNotificationsRead,
  markNotificationRead,
} from "@/api/notifications"
import type { Notification } from "@/types/models"

const ICONS_BY_TYPE: Record<string, React.ComponentType<{ className?: string }>> = {
  new_user_registered: UserPlus,
  admin_broadcast: Megaphone,
}

export function NotificationsBell() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { t, language } = useLanguage()
  const [open, setOpen] = useState(false)

  const { data: unreadData } = useQuery({
    queryKey: [QUERY_KEYS.NOTIFICATIONS.UNREAD_COUNT],
    queryFn: getMyUnreadCount,
    refetchInterval: 60_000,
  })

  const { data: listData, isLoading } = useQuery({
    queryKey: [QUERY_KEYS.NOTIFICATIONS.LIST, { recent: true }],
    queryFn: () => getMyNotifications({ page: 1, limit: 8 }),
    enabled: open,
  })

  const markReadMutation = useMutation({
    mutationFn: (id: string) => markNotificationRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: [QUERY_KEYS.NOTIFICATIONS.LIST],
      })
      queryClient.invalidateQueries({
        queryKey: [QUERY_KEYS.NOTIFICATIONS.UNREAD_COUNT],
      })
    },
  })

  const markAllMutation = useMutation({
    mutationFn: () => markAllNotificationsRead(),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: [QUERY_KEYS.NOTIFICATIONS.LIST],
      })
      queryClient.invalidateQueries({
        queryKey: [QUERY_KEYS.NOTIFICATIONS.UNREAD_COUNT],
      })
    },
  })

  const unreadCount = unreadData ?? 0
  const notifications = listData?.data ?? []

  const handleItemClick = (n: Notification) => {
    if (!n.isRead) markReadMutation.mutate(n._id)
    setOpen(false)

    const data = (n.data ?? {}) as { newUserId?: string }
    if (n.type === "new_user_registered" && data.newUserId) {
      navigate(`/users/${data.newUserId}`)
      return
    }
    navigate(ROUTES.NOTIFICATIONS)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <button
          className="relative flex items-center justify-center w-8 h-8 rounded-full text-muted-foreground hover:text-foreground hover:bg-muted transition-all duration-150"
          title={t("notifications")}
          aria-label={t("notifications")}
        >
          <Bell className="h-4 w-4" />
          {unreadCount > 0 && (
            <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-rose-500 px-1 text-[10px] font-bold leading-none text-white shadow-sm ring-2 ring-background">
              {unreadCount > 99 ? "99+" : unreadCount}
            </span>
          )}
        </button>
      </PopoverTrigger>
      <PopoverContent
        align={language === "ar" ? "start" : "end"}
        className="w-[360px] p-0 overflow-hidden"
      >
        <div className="flex items-center justify-between px-4 py-3 border-b border-border/60">
          <div className="font-semibold text-sm">{t("notifications")}</div>
          {unreadCount > 0 && (
            <button
              onClick={() => markAllMutation.mutate()}
              disabled={markAllMutation.isPending}
              className="text-xs font-medium text-primary hover:underline flex items-center gap-1"
            >
              <CheckCheck className="h-3.5 w-3.5" />
              {t("markAllRead")}
            </button>
          )}
        </div>

        <ScrollArea className="max-h-[360px]">
          {isLoading ? (
            <div className="p-6 text-center text-sm text-muted-foreground">
              {t("loading")}
            </div>
          ) : notifications.length === 0 ? (
            <div className="p-8 flex flex-col items-center gap-2 text-muted-foreground">
              <Inbox className="h-8 w-8 opacity-60" />
              <span className="text-sm font-medium">
                {t("noNotificationsFound")}
              </span>
            </div>
          ) : (
            <ul className="divide-y divide-border/50">
              {notifications.map((n) => {
                const Icon = ICONS_BY_TYPE[n.type] ?? Bell
                return (
                  <li key={n._id}>
                    <button
                      onClick={() => handleItemClick(n)}
                      className={cn(
                        "w-full text-start px-4 py-3 hover:bg-muted/60 transition-colors flex gap-3",
                        !n.isRead && "bg-primary/[0.04]"
                      )}
                    >
                      <div
                        className={cn(
                          "mt-0.5 h-8 w-8 flex-shrink-0 rounded-full flex items-center justify-center",
                          !n.isRead
                            ? "bg-primary/10 text-primary"
                            : "bg-muted text-muted-foreground"
                        )}
                      >
                        <Icon className="h-4 w-4" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center justify-between gap-2">
                          <div
                            className={cn(
                              "text-sm truncate",
                              !n.isRead ? "font-semibold" : "font-medium"
                            )}
                          >
                            {n.title}
                          </div>
                          {!n.isRead && (
                            <span className="h-2 w-2 rounded-full bg-rose-500 flex-shrink-0" />
                          )}
                        </div>
                        {n.body && (
                          <div className="text-xs text-muted-foreground line-clamp-2 mt-0.5">
                            {n.body}
                          </div>
                        )}
                        <div className="text-[11px] text-muted-foreground/70 mt-1">
                          {formatDate(n.createdAt)}
                        </div>
                      </div>
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </ScrollArea>

        <div className="border-t border-border/60 p-2">
          <Button
            variant="ghost"
            className="w-full justify-center text-sm font-semibold"
            onClick={() => {
              setOpen(false)
              navigate(ROUTES.NOTIFICATIONS)
            }}
          >
            {t("viewAllNotifications")}
          </Button>
        </div>
      </PopoverContent>
    </Popover>
  )
}
