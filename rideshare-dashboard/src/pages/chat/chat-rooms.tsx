// Chat Rooms Page: Admin chat monitoring
// View all chat rooms and read messages in read-only mode

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getChatRooms, getChatMessages } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Badge } from "@/components/ui/badge"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL } from "@/lib/constants"
import { formatDate } from "@/lib/utils"
import type { ChatRoom, ChatMessage, UserSummary, TripSummary } from "@/types/models"
import { MessageSquare, Eye, AlertCircle, Users } from "lucide-react"

function isPopulatedTrip(val: string | TripSummary): val is TripSummary {
    return typeof val === "object" && val !== null && "from" in val
}

function isPopulatedUser(val: string | UserSummary): val is UserSummary {
    return typeof val === "object" && val !== null && "name" in val
}

export default function ChatRoomsPage() {
    const [searchParams, setSearchParams] = useSearchParams()
    const page = parseInt(searchParams.get("page") || "1", 10)
    const limit = 20

    const [selectedRoom, setSelectedRoom] = useState<string | null>(null)
    const [messagesOpen, setMessagesOpen] = useState(false)

    const { data, isLoading, error } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.CHAT_ROOMS, { page, limit }],
        queryFn: () => getChatRooms({ page, limit }),
        refetchInterval: DASHBOARD_REFRESH_INTERVAL,
    })

    const { data: messagesData, isLoading: messagesLoading } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.CHAT_MESSAGES, selectedRoom],
        queryFn: () => getChatMessages(selectedRoom!, { page: 1, limit: 100 }),
        enabled: !!selectedRoom && messagesOpen,
    })

    const handlePageChange = (newPage: number) => {
        const newParams = new URLSearchParams(searchParams)
        newParams.set("page", String(newPage))
        setSearchParams(newParams)
    }

    const openMessages = (roomId: string) => {
        setSelectedRoom(roomId)
        setMessagesOpen(true)
    }

    const columns: Column<ChatRoom>[] = [
        {
            key: "trip",
            header: "Trip",
            cell: (room) => (
                <div className="flex flex-col gap-0.5">
                    {isPopulatedTrip(room.tripId) ? (
                        <>
                            <div className="font-semibold text-foreground text-sm">{room.tripId.from?.name} → {room.tripId.to?.name}</div>
                            <div className="text-xs font-medium text-muted-foreground">{formatDate(room.tripId.departureTime)}</div>
                        </>
                    ) : (
                        <span className="text-muted-foreground font-mono text-xs">Trip ID: {room.tripId}</span>
                    )}
                </div>
            ),
        },
        {
            key: "participants",
            header: "Participants",
            cell: (room) => (
                <div className="flex items-center gap-2">
                    <div className="flex -space-x-2">
                        {room.participants.slice(0, 4).map((p, i) => (
                            <div
                                key={i}
                                className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-xs border-2 border-background shadow-sm"
                                title={isPopulatedUser(p.userId) ? p.userId.name : "User"}
                            >
                                {isPopulatedUser(p.userId) ? p.userId.name.charAt(0).toUpperCase() : "?"}
                            </div>
                        ))}
                    </div>
                    <Badge variant="secondary" className="font-semibold shadow-sm">
                        <Users className="w-3 h-3 mr-1" />
                        {room.participants.length}
                    </Badge>
                </div>
            ),
        },
        {
            key: "lastMessage",
            header: "Last Message",
            cell: (room) => (
                <div className="max-w-[250px] truncate text-sm text-muted-foreground">
                    {room.lastMessage || <span className="italic text-muted-foreground/50">No messages yet</span>}
                </div>
            ),
        },
        {
            key: "lastActivity",
            header: "Last Activity",
            cell: (room) => (
                <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">
                    {room.lastMessageTime ? formatDate(room.lastMessageTime) : "—"}
                </div>
            ),
        },
        {
            key: "created",
            header: "Created",
            cell: (room) => <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">{formatDate(room.createdAt)}</div>,
        },
        {
            key: "actions",
            header: "Actions",
            className: "w-[130px]",
            cell: (room) => (
                <div onClick={(e) => e.stopPropagation()}>
                    <Button
                        size="sm"
                        variant="outline"
                        className="font-semibold text-xs shadow-sm"
                        onClick={() => openMessages(room._id)}
                    >
                        <Eye className="mr-1.5 h-3.5 w-3.5" />
                        View Messages
                    </Button>
                </div>
            ),
        },
    ]

    if (error) {
        return (
            <div className="space-y-4 animate-in fade-in duration-500">
                <h1 className="text-4xl font-extrabold tracking-tight">Chat</h1>
                <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
                    <AlertCircle className="w-6 h-6 mr-3" />
                    <span className="font-semibold text-lg">Failed to load chat rooms. Please try again.</span>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
            <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
                <div className="flex items-center gap-4">
                    <div className="bg-cyan-500/10 p-3 rounded-2xl border border-cyan-500/20 shadow-sm hidden sm:block">
                        <MessageSquare className="w-8 h-8 text-cyan-500" />
                    </div>
                    <div>
                        <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">Chat Monitoring</h1>
                        <p className="text-muted-foreground mt-1 text-lg font-medium">
                            Monitor trip chat rooms and review conversations for support purposes.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
                <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
                    <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
                        <h2 className="text-xl font-bold flex items-center">
                            <MessageSquare className="w-5 h-5 mr-3 text-cyan-500" />
                            All Chat Rooms
                        </h2>
                        <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                            <span className="text-muted-foreground">Total:</span> <span className="text-foreground ml-1">{data?.meta?.total || 0}</span>
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
                            emptyMessage="No chat rooms found."
                        />
                    </div>
                </CardContent>
            </Card>

            {/* Messages Dialog */}
            <Dialog open={messagesOpen} onOpenChange={setMessagesOpen}>
                <DialogContent className="sm:max-w-[600px] max-h-[80vh]">
                    <DialogHeader>
                        <DialogTitle className="text-xl font-bold flex items-center">
                            <MessageSquare className="w-5 h-5 mr-2 text-cyan-500" />
                            Chat Messages
                            <Badge variant="secondary" className="ml-2">{messagesData?.meta?.total || 0} messages</Badge>
                        </DialogTitle>
                    </DialogHeader>
                    <ScrollArea className="h-[400px] w-full pr-4">
                        {messagesLoading ? (
                            <div className="flex items-center justify-center h-full">
                                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
                            </div>
                        ) : (messagesData?.data || []).length === 0 ? (
                            <div className="flex items-center justify-center h-full text-muted-foreground">
                                No messages in this chat room.
                            </div>
                        ) : (
                            <div className="space-y-3">
                                {(messagesData?.data || []).map((msg: ChatMessage) => (
                                    <div key={msg._id} className="flex flex-col gap-1 rounded-lg p-3 bg-muted/50 border border-border/40">
                                        <div className="flex items-center justify-between">
                                            <span className="font-semibold text-sm text-foreground">{msg.senderName}</span>
                                            <span className="text-xs text-muted-foreground">{formatDate(msg.createdAt)}</span>
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
