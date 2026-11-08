import { useNavigate, useSearchParams } from "react-router-dom"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { Bell, CheckCheck, ChevronLeft, ChevronRight, Inbox, Megaphone, UserPlus } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { useLanguage } from "@/providers/language-provider"
import { QUERY_KEYS } from "@/lib/constants"
import { cn, formatDate } from "@/lib/utils"
import { notificationLink } from "@/lib/notification-link"
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

const PAGE_SIZE = 20

/**
 * «عرض كل الإشعارات»: every notification sent to the signed-in admin, newest
 * first. (The Notifications page is the platform's broadcast and history.)
 */
export default function MyNotificationsPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { t, language } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const page = Math.max(1, parseInt(searchParams.get("page") || "1", 10) || 1)

  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.NOTIFICATIONS.LIST, { page, limit: PAGE_SIZE }],
    queryFn: () => getMyNotifications({ page, limit: PAGE_SIZE }),
  })
  const { data: unreadCount = 0 } = useQuery({
    queryKey: [QUERY_KEYS.NOTIFICATIONS.UNREAD_COUNT],
    queryFn: getMyUnreadCount,
  })

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.NOTIFICATIONS.LIST] })
    queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.NOTIFICATIONS.UNREAD_COUNT] })
  }
  const markRead = useMutation({ mutationFn: markNotificationRead, onSuccess: refresh })
  const markAll = useMutation({ mutationFn: markAllNotificationsRead, onSuccess: refresh })

  const notifications = data?.data ?? []
  const totalPages = Math.max(1, data?.meta?.totalPages ?? 1)

  const open = (n: Notification) => {
    if (!n.isRead) markRead.mutate(n._id)
    const link = notificationLink(n)
    if (link) navigate(link)
  }
  const goTo = (next: number) => setSearchParams({ page: String(next) })
  const Back = language === "ar" ? ChevronRight : ChevronLeft
  const Forward = language === "ar" ? ChevronLeft : ChevronRight

  return (
    <div className="space-y-6 max-w-3xl">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-3xl font-extrabold tracking-tight">{t("myNotificationsTitle")}</h1>
          <p className="text-muted-foreground mt-1">{t("myNotificationsSubtitle")}</p>
        </div>
        {unreadCount > 0 && (
          <Button variant="outline" onClick={() => markAll.mutate()} disabled={markAll.isPending}>
            <CheckCheck className="h-4 w-4" />
            {t("markAllRead")}
          </Button>
        )}
      </div>

      <Card className="overflow-hidden">
        <CardContent className="p-0">
          {isLoading ? (
            <div className="p-8 text-center text-sm text-muted-foreground">{t("loading")}</div>
          ) : error ? (
            <div className="p-8 text-center text-sm text-destructive">{t("failedToLoadNotifications")}</div>
          ) : notifications.length === 0 ? (
            <div className="p-10 flex flex-col items-center gap-2 text-muted-foreground">
              <Inbox className="h-8 w-8 opacity-60" />
              <span className="text-sm font-medium">{t("noNotificationsFound")}</span>
            </div>
          ) : (
            <ul className="divide-y divide-border/50">
              {notifications.map((n) => {
                const Icon = ICONS_BY_TYPE[n.type] ?? Bell
                return (
                  <li key={n._id}>
                    <button
                      onClick={() => open(n)}
                      className={cn(
                        "w-full text-start px-5 py-4 hover:bg-muted/60 transition-colors flex gap-3",
                        !n.isRead && "bg-primary/[0.04]"
                      )}
                    >
                      <div
                        className={cn(
                          "mt-0.5 h-9 w-9 flex-shrink-0 rounded-full flex items-center justify-center",
                          !n.isRead ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground"
                        )}
                      >
                        <Icon className="h-4 w-4" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center justify-between gap-2">
                          <div className={cn("text-sm", !n.isRead ? "font-semibold" : "font-medium")}>
                            {n.title}
                          </div>
                          {!n.isRead && <span className="h-2 w-2 rounded-full bg-rose-500 flex-shrink-0" />}
                        </div>
                        {n.body && <div className="text-sm text-muted-foreground mt-0.5">{n.body}</div>}
                        <div className="text-xs text-muted-foreground/70 mt-1">{formatDate(n.createdAt)}</div>
                      </div>
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </CardContent>
      </Card>

      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-3">
          <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => goTo(page - 1)}>
            <Back className="h-4 w-4" />
            {t("previous")}
          </Button>
          <span className="text-sm text-muted-foreground">
            {page} / {totalPages}
          </span>
          <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => goTo(page + 1)}>
            {t("next")}
            <Forward className="h-4 w-4" />
          </Button>
        </div>
      )}
    </div>
  )
}
