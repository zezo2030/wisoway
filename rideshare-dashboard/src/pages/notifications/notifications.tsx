// Notifications Page: Broadcast notifications and view notification history
// Admin can send push notifications to all users or filtered by role

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
    getAdminNotifications,
    broadcastNotification,
    getAlertPreferences,
    updateAlertPreference,
    type AdminAlertType,
} from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog"
import { Badge } from "@/components/ui/badge"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL, USER_ROLE_LABELS } from "@/lib/constants"
import { formatDate } from "@/lib/utils"
import type { Notification, UserSummary } from "@/types/models"
import type { UserRole } from "@/types/enums"
import { Bell, Send, AlertCircle, Megaphone, BellRing } from "lucide-react"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"

function isPopulatedUser(val: unknown): val is UserSummary {
    return typeof val === "object" && val !== null && "name" in (val as any)
}

export default function NotificationsPage() {
    const [searchParams, setSearchParams] = useSearchParams()
    const queryClient = useQueryClient()
    const { t } = useLanguage()
    const page = parseInt(searchParams.get("page") || "1", 10)
    const limit = 20

    // Broadcast form state
    const [broadcastOpen, setBroadcastOpen] = useState(false)
    const [title, setTitle] = useState("")
    const [body, setBody] = useState("")
    const [targetRole, setTargetRole] = useState<string>("all")

    const { data, isLoading, error } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.NOTIFICATIONS, { page, limit }],
        queryFn: () => getAdminNotifications({ page, limit }),
        refetchInterval: DASHBOARD_REFRESH_INTERVAL,
    })

    const { data: alertPreferences = [] } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.NOTIFICATIONS, "alert-preferences"],
        queryFn: getAlertPreferences,
    })

    const broadcastMutation = useMutation({
        mutationFn: () =>
            broadcastNotification({
                title,
                body,
                targetRole: targetRole !== "all" ? (targetRole as UserRole) : undefined,
            }),
        onSuccess: (result) => {
            queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.NOTIFICATIONS] })
            toast.success(t("notificationSentSuccess").replace("{count}", String(result.sent)))
            setBroadcastOpen(false)
            setTitle("")
            setBody("")
            setTargetRole("all")
        },
        onError: () => {
            toast.error(t("notificationSendFailed"))
        },
    })

    const preferenceMutation = useMutation({
        mutationFn: ({ alertType, enabled }: { alertType: AdminAlertType; enabled: boolean }) =>
            updateAlertPreference(alertType, enabled),
        onSuccess: () => {
            queryClient.invalidateQueries({
                queryKey: [QUERY_KEYS.ADMIN.NOTIFICATIONS, "alert-preferences"],
            })
            toast.success(t("alertPreferenceSaved"))
        },
        onError: () => {
            toast.error(t("alertPreferenceSaveFailed"))
        },
    })

    const preferenceEnabled = (alertType: AdminAlertType) =>
        alertPreferences.find((preference) => preference.alertType === alertType)?.enabled ?? true

    const alertPreferenceItems: Array<{
        alertType: AdminAlertType
        title: string
        description: string
    }> = [
        {
            alertType: "driver_registration",
            title: t("driverRegistrationAlerts"),
            description: t("driverRegistrationAlertsDesc"),
        },
        {
            alertType: "fee_payment",
            title: t("feePaymentAlerts"),
            description: t("feePaymentAlertsDesc"),
        },
    ]

    const handlePageChange = (newPage: number) => {
        const newParams = new URLSearchParams(searchParams)
        newParams.set("page", String(newPage))
        setSearchParams(newParams)
    }

    const notificationTypeBadge = (type: string) => {
        const colors: Record<string, string> = {
            admin_broadcast: "bg-purple-500/10 text-purple-600 border-purple-500/20",
            role_changed: "bg-blue-500/10 text-blue-600 border-blue-500/20",
            booking_cancelled: "bg-red-500/10 text-red-600 border-red-500/20",
            vehicle_verified: "bg-emerald-500/10 text-emerald-600 border-emerald-500/20",
            vehicle_rejected: "bg-orange-500/10 text-orange-600 border-orange-500/20",
            chat_message: "bg-cyan-500/10 text-cyan-600 border-cyan-500/20",
            account_banned: "bg-red-500/10 text-red-600 border-red-500/20",
            account_unbanned: "bg-green-500/10 text-green-600 border-green-500/20",
        }
        const className = colors[type] || "bg-muted text-muted-foreground border-border"
        return (
            <Badge variant="outline" className={`${className} font-semibold text-xs capitalize shadow-sm`}>
                {type.replace(/_/g, " ")}
            </Badge>
        )
    }

    const columns: Column<Notification>[] = [
        {
            key: "user",
            header: t("recipient"),
            cell: (notification) => {
                const user = (notification as any).userId
                return (
                    <div className="flex items-center gap-3 py-1">
                        {isPopulatedUser(user) ? (
                            <>
                                <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20 flex-shrink-0">
                                    {user.name.charAt(0).toUpperCase()}
                                </div>
                                <div>
                                    <div className="font-semibold text-foreground">{user.name}</div>
                                    <div className="text-xs font-medium text-muted-foreground">{user.email}</div>
                                </div>
                            </>
                        ) : (
                            <span className="text-muted-foreground font-mono text-xs">ID: {typeof notification.userId === "string" ? notification.userId : (notification.userId as UserSummary)?.name ?? ""}</span>
                        )}
                    </div>
                )
            },
        },
        {
            key: "type",
            header: t("type"),
            cell: (notification) => notificationTypeBadge(notification.type),
        },
        {
            key: "title",
            header: t("title"),
            cell: (notification) => <div className="font-semibold text-foreground text-sm">{notification.title}</div>,
        },
        {
            key: "body",
            header: t("messageColumn"),
            cell: (notification) => (
                <div className="max-w-[300px] truncate text-sm text-muted-foreground">
                    {notification.body || <span className="italic text-muted-foreground/50">{t("noMessage")}</span>}
                </div>
            ),
        },
        {
            key: "read",
            header: t("read"),
            cell: (notification) => (
                <Badge variant={notification.isRead ? "default" : "secondary"} className="shadow-sm">
                    {notification.isRead ? t("read") : t("unread")}
                </Badge>
            ),
        },
        {
            key: "created",
            header: t("sentColumn"),
            cell: (notification) => <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">{formatDate(notification.createdAt)}</div>,
        },
    ]

    if (error) {
        return (
            <div className="space-y-4 animate-in fade-in duration-500">
                <h1 className="text-4xl font-extrabold tracking-tight">{t("notificationsTitle")}</h1>
                <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
                    <AlertCircle className="w-6 h-6 mr-3" />
                    <span className="font-semibold text-lg">{t("failedToLoadNotifications")}</span>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
            <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
                <div className="flex items-center gap-4">
                    <div className="bg-violet-500/10 p-3 rounded-2xl border border-violet-500/20 shadow-sm hidden sm:block">
                        <Bell className="w-8 h-8 text-violet-500" />
                    </div>
                    <div>
                        <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">{t("notificationsTitle")}</h1>
                        <p className="text-muted-foreground mt-1 text-lg font-medium">
                            {t("notificationsSubtitle")}
                        </p>
                    </div>
                </div>

                <Dialog open={broadcastOpen} onOpenChange={setBroadcastOpen}>
                    <DialogTrigger asChild>
                        <Button className="bg-violet-600 hover:bg-violet-700 text-white font-semibold shadow-md shadow-violet-600/20">
                            <Megaphone className="mr-2 h-4 w-4" />
                            {t("broadcastNotification")}
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="sm:max-w-[500px]">
                        <DialogHeader>
                            <DialogTitle className="text-xl font-bold">{t("sendBroadcastNotification")}</DialogTitle>
                            <DialogDescription>
                                {t("broadcastDesc")}
                            </DialogDescription>
                        </DialogHeader>
                        <div className="space-y-4 py-4">
                            <div className="space-y-2">
                                <Label htmlFor="title" className="font-semibold">{t("title")}</Label>
                                <Input
                                    id="title"
                                    value={title}
                                    onChange={(e) => setTitle(e.target.value)}
                                    placeholder={t("notificationTitlePlaceholder")}
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="body" className="font-semibold">{t("messageColumn")}</Label>
                                <Textarea
                                    id="body"
                                    value={body}
                                    onChange={(e) => setBody(e.target.value)}
                                    placeholder={t("notificationMessagePlaceholder")}
                                    rows={4}
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="target" className="font-semibold">{t("targetAudience")}</Label>
                                <Select value={targetRole} onValueChange={setTargetRole}>
                                    <SelectTrigger>
                                        <SelectValue placeholder={t("selectTarget")} />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="all">{t("allUsers")}</SelectItem>
                                        {Object.entries(USER_ROLE_LABELS).map(([key, label]) => (
                                            <SelectItem key={key} value={key}>{label}s</SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button variant="outline" onClick={() => setBroadcastOpen(false)}>
                                {t("cancel")}
                            </Button>
                            <Button
                                onClick={() => broadcastMutation.mutate()}
                                disabled={!title || !body || broadcastMutation.isPending}
                                className="bg-violet-600 hover:bg-violet-700 text-white"
                            >
                                <Send className="mr-2 h-4 w-4" />
                                {broadcastMutation.isPending ? t("sending") : t("sendNotification")}
                            </Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10">
                <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
                    <h2 className="text-xl font-bold flex items-center">
                        <BellRing className="w-5 h-5 mr-3 text-violet-500" />
                        {t("adminAlertPreferences")}
                    </h2>
                </CardHeader>
                <CardContent className="p-6">
                    <div className="grid gap-4 md:grid-cols-2">
                        {alertPreferenceItems.map((item) => {
                            const enabled = preferenceEnabled(item.alertType)
                            return (
                                <label
                                    key={item.alertType}
                                    className="flex min-h-28 items-start gap-4 rounded-lg border border-border/60 bg-background/70 p-4 shadow-sm"
                                >
                                    <input
                                        type="checkbox"
                                        className="mt-1 h-5 w-5 accent-violet-600"
                                        checked={enabled}
                                        disabled={preferenceMutation.isPending}
                                        onChange={(event) =>
                                            preferenceMutation.mutate({
                                                alertType: item.alertType,
                                                enabled: event.target.checked,
                                            })
                                        }
                                    />
                                    <span className="space-y-1">
                                        <span className="block text-sm font-bold text-foreground">{item.title}</span>
                                        <span className="block text-sm text-muted-foreground">{item.description}</span>
                                        <Badge variant={enabled ? "default" : "secondary"} className="mt-2">
                                            {enabled ? t("enabled") : t("disabled")}
                                        </Badge>
                                    </span>
                                </label>
                            )
                        })}
                    </div>
                </CardContent>
            </Card>

            <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
                <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
                    <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
                        <h2 className="text-xl font-bold flex items-center">
                            <Bell className="w-5 h-5 mr-3 text-violet-500" />
                            {t("notificationHistory")}
                        </h2>
                        <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                            <span className="text-muted-foreground">{t("total")}:</span> <span className="text-foreground ml-1">{data?.meta?.total || 0}</span>
                        </div>
                    </div>
                </CardHeader>

                <CardContent className="p-0">
                    <div className="overflow-x-auto">
                        <DataTable
                            columns={columns}
                            data={data?.data || []}
                            page={page}
                            totalPages={data?.meta.totalPages || 0}
                            total={data?.meta.total || 0}
                            onPageChange={handlePageChange}
                            pageSize={limit}
                            loading={isLoading}
                            emptyMessage={t("noNotificationsFound")}
                        />
                    </div>
                </CardContent>
            </Card>
        </div>
    )
}
