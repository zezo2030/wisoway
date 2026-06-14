// Chat Rooms Page: Admin chat monitoring — organised by trips
// Trips are the top-level category; selecting a trip shows its chat rooms.

import { useMemo, useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { getChatRoomsForTrip, getDashboardChatMessages, getTrips } from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Badge } from "@/components/ui/badge"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { QUERY_KEYS } from "@/lib/constants"
import { cn, formatDate, formatDateTime, getTripLocationName } from "@/lib/utils"
import type { ChatMessage, ChatRoom, Trip, UserSummary } from "@/types/models"
import {
    AlertCircle,
    CalendarDays,
    ChevronRight,
    Eye,
    Loader2,
    MessageSquare,
    Navigation,
    Users,
} from "lucide-react"
import { useLanguage } from "@/providers/language-provider"

// ─── helpers ────────────────────────────────────────────────────────────────

function isPopulatedUser(val: string | UserSummary): val is UserSummary {
    return typeof val === "object" && val !== null && "name" in val
}

function getTripId(trip: Trip): string {
    return (trip as Trip & { id?: string })._id ?? (trip as Trip & { id?: string }).id ?? ""
}

function getRoomId(room: ChatRoom): string {
    return (room as ChatRoom & { id?: string })._id ?? (room as ChatRoom & { id?: string }).id ?? ""
}

// ─── sub-components ─────────────────────────────────────────────────────────

function TripCard({
    trip,
    selected,
    onClick,
}: {
    trip: Trip
    selected: boolean
    onClick: () => void
}) {
    const fromName = getTripLocationName(trip, "from") || "—"
    const toName = getTripLocationName(trip, "to") || "—"

    return (
        <button
            type="button"
            onClick={onClick}
            className={cn(
                "w-full text-left rounded-xl border px-4 py-3 transition-all duration-150",
                "hover:border-cyan-500/50 hover:bg-cyan-500/5",
                selected
                    ? "border-cyan-500/70 bg-cyan-500/10 shadow-sm"
                    : "border-border/50 bg-card/60",
            )}
        >
            <div className="flex items-center justify-between gap-2">
                <div className="flex items-center gap-3 min-w-0">
                    <div className={cn(
                        "p-2 rounded-lg border flex-shrink-0",
                        selected
                            ? "bg-cyan-500/20 border-cyan-500/40 text-cyan-500"
                            : "bg-primary/10 border-primary/20 text-primary",
                    )}>
                        <Navigation className="w-4 h-4" />
                    </div>
                    <div className="min-w-0">
                        <div className="font-semibold text-sm text-foreground truncate">
                            {fromName} → {toName}
                        </div>
                        <div className="flex items-center gap-1 mt-0.5 text-xs text-muted-foreground">
                            <CalendarDays className="w-3 h-3 flex-shrink-0" />
                            {formatDateTime(trip.departureTime)}
                        </div>
                    </div>
                </div>
                <ChevronRight className={cn(
                    "w-4 h-4 flex-shrink-0 transition-transform",
                    selected ? "rotate-90 text-cyan-500" : "text-muted-foreground/50",
                )} />
            </div>
        </button>
    )
}

function ChatRoomCard({
    room,
    onViewMessages,
}: {
    room: ChatRoom
    onViewMessages: (id: string) => void
}) {
    const { t } = useLanguage()
    return (
        <div className="rounded-xl border border-border/50 bg-card/70 px-4 py-3 flex flex-col gap-2 shadow-sm">
            {/* Participants row */}
            <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                    <div className="flex -space-x-2">
                        {room.participants.slice(0, 4).map((p, i) => (
                            <div
                                key={i}
                                className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-xs border-2 border-background shadow-sm"
                                title={isPopulatedUser(p.userId) ? p.userId.name : "User"}
                            >
                                {isPopulatedUser(p.userId)
                                    ? p.userId.name.charAt(0).toUpperCase()
                                    : "?"}
                            </div>
                        ))}
                    </div>
                    <Badge variant="secondary" className="font-semibold text-xs shadow-sm">
                        <Users className="w-3 h-3 mr-1" />
                        {room.participants.length}
                    </Badge>
                </div>
                <Button
                    size="sm"
                    variant="outline"
                    className="font-semibold text-xs shadow-sm h-8"
                    onClick={() => onViewMessages(getRoomId(room))}
                >
                    <Eye className="mr-1.5 h-3.5 w-3.5" />
                    {t("viewMessages")}
                </Button>
            </div>

            {/* Last message preview */}
            {room.lastMessage && (
                <p className="text-xs text-muted-foreground truncate border-t border-border/30 pt-2">
                    {room.lastMessage}
                </p>
            )}

            {/* Timestamps */}
            <div className="flex items-center gap-3 text-xs text-muted-foreground/70">
                {room.lastMessageTime && (
                    <span>{t("lastActivity")}: {formatDate(room.lastMessageTime)}</span>
                )}
                <span className="ml-auto">{t("createdAt")}: {formatDate(room.createdAt)}</span>
            </div>
        </div>
    )
}

// ─── main page ───────────────────────────────────────────────────────────────

export default function ChatRoomsPage() {
    const { t } = useLanguage()

    // Date filter state
    const [dateFrom, setDateFrom] = useState("")
    const [dateTo, setDateTo] = useState("")

    // Selected trip
    const [selectedTripId, setSelectedTripId] = useState<string | null>(null)

    // Messages dialog
    const [selectedRoomId, setSelectedRoomId] = useState<string | null>(null)
    const [messagesOpen, setMessagesOpen] = useState(false)

    // ── fetch a large page of trips (filter client-side by date) ──
    const { data: tripsData, isLoading: tripsLoading, error: tripsError } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.TRIPS, { page: 1, limit: 100 }],
        queryFn: () => getTrips({ page: 1, limit: 100 }),
    })

    const filteredTrips = useMemo(() => {
        const trips = tripsData?.data ?? []
        return trips.filter((trip) => {
            const dep = new Date(trip.departureTime).getTime()
            if (dateFrom && dep < new Date(dateFrom).getTime()) return false
            if (dateTo && dep > new Date(dateTo + "T23:59:59").getTime()) return false
            return true
        })
    }, [tripsData, dateFrom, dateTo])

    // ── fetch chat rooms for selected trip ──
    const { data: roomsData, isLoading: roomsLoading } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.CHAT_ROOMS, selectedTripId],
        queryFn: () => getChatRoomsForTrip(selectedTripId!),
        enabled: !!selectedTripId,
    })

    // ── fetch messages for selected room ──
    const { data: messagesData, isLoading: messagesLoading } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.CHAT_MESSAGES, selectedRoomId],
        queryFn: () => getDashboardChatMessages(selectedRoomId!, { page: 1, limit: 100 }),
        enabled: !!selectedRoomId && messagesOpen,
    })

    const openMessages = (roomId: string) => {
        if (!roomId) return
        setSelectedRoomId(roomId)
        setMessagesOpen(true)
    }

    const selectedTrip = filteredTrips.find((t) => getTripId(t) === selectedTripId)

    // ── error state ──
    if (tripsError) {
        return (
            <div className="space-y-4 animate-in fade-in duration-500">
                <h1 className="text-4xl font-extrabold tracking-tight">{t("chatMonitoring")}</h1>
                <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
                    <AlertCircle className="w-6 h-6 mr-3" />
                    <span className="font-semibold text-lg">{t("failedToLoadTrips")}</span>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
            {/* ── Page header ── */}
            <div className="flex items-center gap-4">
                <div className="bg-cyan-500/10 p-3 rounded-2xl border border-cyan-500/20 shadow-sm hidden sm:block">
                    <MessageSquare className="w-8 h-8 text-cyan-500" />
                </div>
                <div>
                    <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
                        {t("chatMonitoring")}
                    </h1>
                    <p className="text-muted-foreground mt-1 text-lg font-medium">
                        {t("chatByTripSubtitle")}
                    </p>
                </div>
            </div>

            {/* ── Date filter bar ── */}
            <Card className="border-border/50 bg-card/60 backdrop-blur-xl shadow-sm">
                <CardContent className="py-4 px-6">
                    <div className="flex flex-wrap items-end gap-4">
                        <div className="flex items-center gap-2 text-sm font-semibold text-muted-foreground">
                            <CalendarDays className="w-4 h-4" />
                            {t("filterByDate")}
                        </div>
                        <div className="flex flex-wrap gap-4">
                            <div className="flex flex-col gap-1">
                                <Label className="text-xs text-muted-foreground">{t("from")}</Label>
                                <Input
                                    type="date"
                                    value={dateFrom}
                                    onChange={(e) => {
                                        setDateFrom(e.target.value)
                                        setSelectedTripId(null)
                                    }}
                                    className="h-8 text-sm w-36"
                                />
                            </div>
                            <div className="flex flex-col gap-1">
                                <Label className="text-xs text-muted-foreground">{t("to")}</Label>
                                <Input
                                    type="date"
                                    value={dateTo}
                                    onChange={(e) => {
                                        setDateTo(e.target.value)
                                        setSelectedTripId(null)
                                    }}
                                    className="h-8 text-sm w-36"
                                />
                            </div>
                            {(dateFrom || dateTo) && (
                                <div className="flex flex-col gap-1">
                                    <Label className="text-xs opacity-0">x</Label>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        className="h-8 text-xs text-muted-foreground"
                                        onClick={() => { setDateFrom(""); setDateTo(""); setSelectedTripId(null) }}
                                    >
                                        {t("clearFilter")}
                                    </Button>
                                </div>
                            )}
                        </div>
                        <div className="ml-auto text-sm text-muted-foreground font-medium">
                            {filteredTrips.length} {t("nav_trips")}
                        </div>
                    </div>
                </CardContent>
            </Card>

            {/* ── Two-panel layout ── */}
            <div className="grid grid-cols-1 lg:grid-cols-[340px_1fr] gap-6 items-start">

                {/* LEFT: trips list */}
                <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl dark:border-white/10">
                    <CardHeader className="bg-muted/30 border-b border-border/40 pb-4 pt-5 px-5">
                        <h2 className="text-base font-bold flex items-center gap-2">
                            <Navigation className="w-4 h-4 text-primary" />
                            {t("nav_trips")}
                        </h2>
                    </CardHeader>
                    <CardContent className="p-3">
                        {tripsLoading ? (
                            <div className="flex items-center justify-center py-16">
                                <Loader2 className="w-6 h-6 animate-spin text-muted-foreground" />
                            </div>
                        ) : filteredTrips.length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-16 gap-2 text-muted-foreground text-sm">
                                <Navigation className="w-8 h-8 opacity-30" />
                                {t("noTripsFound")}
                            </div>
                        ) : (
                            <ScrollArea className="h-[520px] pr-2">
                                <div className="flex flex-col gap-2">
                                    {filteredTrips.map((trip) => {
                                        const id = getTripId(trip)
                                        return (
                                            <TripCard
                                                key={id}
                                                trip={trip}
                                                selected={selectedTripId === id}
                                                onClick={() => setSelectedTripId(id === selectedTripId ? null : id)}
                                            />
                                        )
                                    })}
                                </div>
                            </ScrollArea>
                        )}
                    </CardContent>
                </Card>

                {/* RIGHT: chat rooms for selected trip */}
                <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl dark:border-white/10 min-h-[300px]">
                    <CardHeader className="bg-muted/30 border-b border-border/40 pb-4 pt-5 px-5">
                        <div className="flex items-center gap-2">
                            <MessageSquare className="w-4 h-4 text-cyan-500" />
                            <h2 className="text-base font-bold">
                                {selectedTrip
                                    ? `${getTripLocationName(selectedTrip, "from") || "?"} → ${getTripLocationName(selectedTrip, "to") || "?"}`
                                    : t("selectATripToViewChats")}
                            </h2>
                            {selectedTrip && (
                                <Badge variant="secondary" className="ml-auto font-semibold text-xs">
                                    {roomsData?.meta?.total ?? roomsData?.data?.length ?? 0} {t("chatRoomsCount")}
                                </Badge>
                            )}
                        </div>
                        {selectedTrip && (
                            <p className="text-xs text-muted-foreground mt-1 flex items-center gap-1">
                                <CalendarDays className="w-3 h-3" />
                                {formatDateTime(selectedTrip.departureTime)}
                            </p>
                        )}
                    </CardHeader>

                    <CardContent className="p-4">
                        {!selectedTripId ? (
                            <div className="flex flex-col items-center justify-center py-20 gap-3 text-muted-foreground/60">
                                <MessageSquare className="w-12 h-12 opacity-20" />
                                <p className="text-sm font-medium">{t("selectATripToViewChats")}</p>
                            </div>
                        ) : roomsLoading ? (
                            <div className="flex items-center justify-center py-20">
                                <Loader2 className="w-6 h-6 animate-spin text-muted-foreground" />
                            </div>
                        ) : (roomsData?.data ?? []).length === 0 ? (
                            <div className="flex flex-col items-center justify-center py-20 gap-3 text-muted-foreground/60">
                                <MessageSquare className="w-10 h-10 opacity-20" />
                                <p className="text-sm font-medium">{t("noChatRoomsFound")}</p>
                            </div>
                        ) : (
                            <div className="flex flex-col gap-3">
                                {(roomsData?.data ?? []).map((room) => (
                                    <ChatRoomCard
                                        key={room._id}
                                        room={room}
                                        onViewMessages={openMessages}
                                    />
                                ))}
                            </div>
                        )}
                    </CardContent>
                </Card>
            </div>

            {/* ── Messages dialog ── */}
            <Dialog open={messagesOpen} onOpenChange={setMessagesOpen}>
                <DialogContent className="sm:max-w-[600px] max-h-[80vh]">
                    <DialogHeader>
                        <DialogTitle className="text-xl font-bold flex items-center gap-2">
                            <MessageSquare className="w-5 h-5 text-cyan-500" />
                            {t("chatMessages")}
                            <Badge variant="secondary" className="ml-1">
                                {messagesData?.meta?.total ?? messagesData?.data?.length ?? 0} {t("messages")}
                            </Badge>
                        </DialogTitle>
                    </DialogHeader>
                    <ScrollArea className="h-[420px] w-full pr-4">
                        {messagesLoading ? (
                            <div className="flex items-center justify-center h-40">
                                <Loader2 className="w-8 h-8 animate-spin text-muted-foreground" />
                            </div>
                        ) : (messagesData?.data ?? []).length === 0 ? (
                            <div className="flex items-center justify-center h-40 text-muted-foreground text-sm">
                                {t("noMessagesInRoom")}
                            </div>
                        ) : (
                            <div className="space-y-3">
                                {(messagesData?.data ?? []).map((msg: ChatMessage) => (
                                    <div
                                        key={msg._id || `${msg.senderId}-${msg.createdAt}-${msg.text}`}
                                        className="flex flex-col gap-1 rounded-lg p-3 bg-muted/50 border border-border/40"
                                    >
                                        <div className="flex items-center justify-between">
                                            <span className="font-semibold text-sm text-foreground">
                                                {msg.senderName}
                                            </span>
                                            <span className="text-xs text-muted-foreground">
                                                {formatDateTime(msg.createdAt)}
                                            </span>
                                        </div>
                                        <p className="text-sm text-foreground/80">{msg.text}</p>
                                    </div>
                                ))}
                            </div>
                        )}
                    </ScrollArea>
                </DialogContent>
            </Dialog>
        </div>
    )
}
