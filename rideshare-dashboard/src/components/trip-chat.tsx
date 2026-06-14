// TripChat: Read-only admin viewer for all 1:1 driver-passenger chats on a trip.
// Lists every passenger (from bookings) and shows their chat if a room exists,
// otherwise indicates that chat hasn't been started yet.
import { useMemo, useState } from "react"
import { useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getBookingsForTrip, getChatRoomsForTrip, getDashboardChatMessages } from "@/api/admin"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDateTime } from "@/lib/utils"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { MessageSquare, ChevronDown, ChevronUp, Clock, Loader2, ExternalLink, User, MessageCircleOff } from "lucide-react"
import type { Booking, ChatMessage, ChatRoom, UserSummary } from "@/types/models"

const AVATAR_COLORS = [
  "bg-violet-500",
  "bg-blue-500",
  "bg-emerald-500",
  "bg-rose-500",
  "bg-amber-500",
  "bg-cyan-500",
  "bg-pink-500",
  "bg-indigo-500",
]

function avatarColor(name: string) {
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash)
  return AVATAR_COLORS[Math.abs(hash) % AVATAR_COLORS.length]
}

function getRoomId(room: ChatRoom): string | null {
  const data = room as unknown as Record<string, unknown>
  if (typeof data._id === "string" && data._id.length > 0) return data._id
  if (typeof data.id === "string" && data.id.length > 0) return data.id
  return null
}

function isPopulatedUser(val: string | UserSummary): val is UserSummary {
  return typeof val === "object" && val !== null && "name" in val
}

function getBookingPassengerId(booking: Booking): string | null {
  if (typeof booking.userId === "string") return booking.userId
  if (isPopulatedUser(booking.userId)) {
    const u = booking.userId as unknown as { _id?: string; id?: string }
    return u._id || u.id || null
  }
  return null
}

function getBookingPassengerName(booking: Booking): string {
  if (isPopulatedUser(booking.userId)) return booking.userId.name
  return "Unknown passenger"
}

function getBookingPassengerEmail(booking: Booking): string | null {
  if (isPopulatedUser(booking.userId)) return booking.userId.email ?? null
  return null
}

interface PassengerRow {
  passengerId: string
  name: string
  email: string | null
  room: ChatRoom | null
  roomId: string | null
}

function MessageBubble({ msg, isFirst }: { msg: ChatMessage; isFirst: boolean }) {
  const initials = msg.senderName
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase()

  return (
    <div className="flex items-start gap-3 group">
      {isFirst ? (
        <div
          className={`flex-shrink-0 w-9 h-9 rounded-full ${avatarColor(msg.senderName)} flex items-center justify-center text-white font-bold text-xs shadow-sm`}
          title={msg.senderName}
        >
          {initials}
        </div>
      ) : (
        <div className="flex-shrink-0 w-9" />
      )}

      <div className="flex-1 min-w-0">
        {isFirst && (
          <div className="flex items-baseline gap-2 mb-1">
            <span className="text-sm font-bold text-foreground leading-tight">{msg.senderName}</span>
            <span className="text-[10px] text-muted-foreground font-medium whitespace-nowrap">
              {formatDateTime(msg.createdAt)}
            </span>
          </div>
        )}
        <div className="bg-muted/50 border border-border/40 rounded-2xl rounded-tl-sm px-4 py-2.5 text-sm text-foreground/90 leading-relaxed max-w-[85%] w-fit shadow-sm">
          {msg.text}
        </div>
        {!isFirst && (
          <div className="text-[10px] text-muted-foreground/0 group-hover:text-muted-foreground transition-colors mt-1 pl-1">
            {formatDateTime(msg.createdAt)}
          </div>
        )}
      </div>
    </div>
  )
}

interface TripChatProps {
  tripId: string
}

export function TripChat({ tripId }: TripChatProps) {
  const navigate = useNavigate()
  const [expanded, setExpanded] = useState(false)
  const [selectedPassengerId, setSelectedPassengerId] = useState<string | null>(null)
  const [msgPage, setMsgPage] = useState(1)
  const MSG_LIMIT = 200

  const { data: bookingsData, isLoading: bookingsLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIP, tripId, "bookings"],
    queryFn: () => getBookingsForTrip(tripId),
    enabled: !!tripId && expanded,
  })

  const { data: roomsData, isLoading: roomsLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.CHAT_ROOMS, "byTripPg", tripId],
    queryFn: () => getChatRoomsForTrip(tripId),
    enabled: !!tripId && expanded,
  })

  const passengers: PassengerRow[] = useMemo(() => {
    const bookings: Booking[] = bookingsData?.data ?? []
    const rooms: ChatRoom[] = roomsData?.data ?? []
    const roomByPassenger = new Map<string, ChatRoom>()
    for (const r of rooms) {
      if (r.passengerId) roomByPassenger.set(r.passengerId, r)
    }

    const seen = new Set<string>()
    const rows: PassengerRow[] = []
    for (const b of bookings) {
      const pid = getBookingPassengerId(b)
      if (!pid || seen.has(pid)) continue
      seen.add(pid)
      const room = roomByPassenger.get(pid) ?? null
      rows.push({
        passengerId: pid,
        name: getBookingPassengerName(b),
        email: getBookingPassengerEmail(b),
        room,
        roomId: room ? getRoomId(room) : null,
      })
    }
    // Include any rooms whose passenger isn't in bookings (e.g. cancelled booking)
    for (const r of rooms) {
      if (!r.passengerId || seen.has(r.passengerId)) continue
      seen.add(r.passengerId)
      rows.push({
        passengerId: r.passengerId,
        name: r.passenger?.name || "Unknown passenger",
        email: r.passenger?.email ?? null,
        room: r,
        roomId: getRoomId(r),
      })
    }
    return rows
  }, [bookingsData, roomsData])

  const effectivePassengerId = useMemo(() => {
    if (selectedPassengerId && passengers.some((p) => p.passengerId === selectedPassengerId)) {
      return selectedPassengerId
    }
    // Prefer the first passenger that has a room
    const firstWithRoom = passengers.find((p) => p.roomId)
    if (firstWithRoom) return firstWithRoom.passengerId
    return passengers.length > 0 ? passengers[0].passengerId : null
  }, [passengers, selectedPassengerId])

  const selected = passengers.find((p) => p.passengerId === effectivePassengerId) ?? null

  const { data: messagesData, isLoading: msgsLoading, isFetching } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.CHAT_MESSAGES, "pg", selected?.roomId, msgPage, MSG_LIMIT],
    queryFn: () => getDashboardChatMessages(selected!.roomId!, { page: msgPage, limit: MSG_LIMIT }),
    enabled: !!selected?.roomId && expanded,
  })

  const messages: ChatMessage[] = messagesData?.data ?? []
  const grouped = messages.map((msg, i) => ({
    msg,
    isFirst: i === 0 || messages[i - 1].senderId !== msg.senderId,
  }))

  const loadingTopLevel = bookingsLoading || roomsLoading
  const roomsCount = passengers.filter((p) => p.roomId).length

  return (
    <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl overflow-hidden">
      <CardHeader
        className="border-b border-border/40 pb-4 pt-5 cursor-pointer select-none hover:bg-muted/20 transition-colors"
        onClick={() => setExpanded((v) => !v)}
      >
        <div className="flex items-center justify-between gap-2">
          <CardTitle className="text-lg font-bold flex items-center gap-3">
            <div className="bg-cyan-500/10 p-2 rounded-xl border border-cyan-500/20">
              <MessageSquare className="w-5 h-5 text-cyan-500" />
            </div>
            <span>Trip Chats</span>
            {expanded && loadingTopLevel ? (
              <Loader2 className="w-4 h-4 animate-spin text-muted-foreground" />
            ) : expanded && passengers.length > 0 ? (
              <div className="flex items-center gap-2">
                <Badge variant="secondary" className="font-semibold text-xs">
                  <User className="w-3 h-3 mr-1" />
                  {passengers.length} {passengers.length === 1 ? "passenger" : "passengers"}
                </Badge>
                <Badge variant="outline" className="font-medium text-xs">
                  {roomsCount} active {roomsCount === 1 ? "chat" : "chats"}
                </Badge>
              </div>
            ) : null}
          </CardTitle>
          <div className="flex items-center gap-1">
            <Button
              variant="outline"
              size="sm"
              className="rounded-full text-xs font-semibold"
              onClick={(e) => {
                e.stopPropagation()
                navigate(`/trips/${tripId}/chat`)
              }}
            >
              Full Live Chat
              <ExternalLink className="w-3.5 h-3.5 ml-1.5" />
            </Button>
            <Button variant="ghost" size="icon" className="rounded-full" onClick={(e) => { e.stopPropagation(); setExpanded(v => !v) }}>
              {expanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
            </Button>
          </div>
        </div>
      </CardHeader>

      {expanded && (
        <CardContent className="p-0">
          {loadingTopLevel && (
            <div className="flex items-center justify-center py-16">
              <Loader2 className="w-8 h-8 animate-spin text-primary" />
            </div>
          )}

          {!loadingTopLevel && passengers.length === 0 && (
            <div className="flex flex-col items-center justify-center py-16 text-muted-foreground gap-3">
              <MessageCircleOff className="w-12 h-12 opacity-30" />
              <p className="font-semibold text-base">No passengers on this trip</p>
            </div>
          )}

          {!loadingTopLevel && passengers.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-[280px_1fr] min-h-[520px]">
              {/* Passengers list */}
              <div className="border-r border-border/40 bg-muted/10">
                <div className="px-4 py-3 border-b border-border/30">
                  <span className="text-xs font-bold text-muted-foreground uppercase tracking-widest">Passengers</span>
                </div>
                <ScrollArea className="h-[472px]">
                  <div className="p-2 space-y-1">
                    {passengers.map((p) => {
                      const isSelected = p.passengerId === effectivePassengerId
                      const hasRoom = !!p.roomId
                      return (
                        <button
                          key={p.passengerId}
                          onClick={() => {
                            setSelectedPassengerId(p.passengerId)
                            setMsgPage(1)
                          }}
                          className={`w-full text-left flex items-start gap-3 p-3 rounded-xl transition-colors border ${
                            isSelected
                              ? "bg-primary/10 border-primary/30"
                              : "border-transparent hover:bg-muted/40"
                          }`}
                        >
                          <div
                            className={`flex-shrink-0 w-9 h-9 rounded-full ${avatarColor(p.name)} flex items-center justify-center text-white font-bold text-xs shadow-sm`}
                          >
                            {p.name.charAt(0).toUpperCase()}
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-baseline justify-between gap-2">
                              <span className="text-sm font-bold text-foreground truncate">{p.name}</span>
                              {p.room?.lastMessageTime && (
                                <span className="text-[10px] text-muted-foreground whitespace-nowrap">
                                  {formatDateTime(p.room.lastMessageTime)}
                                </span>
                              )}
                            </div>
                            {hasRoom ? (
                              <p className="text-xs text-muted-foreground truncate mt-0.5">
                                {p.room?.lastMessage || <span className="italic opacity-60">No messages yet</span>}
                              </p>
                            ) : (
                              <p className="text-xs text-amber-600 dark:text-amber-400 truncate mt-0.5 italic">
                                Chat not started
                              </p>
                            )}
                          </div>
                        </button>
                      )
                    })}
                  </div>
                </ScrollArea>
              </div>

              {/* Messages panel */}
              <div className="flex flex-col">
                {selected && (
                  <div className="flex items-center gap-3 px-6 py-3 border-b border-border/30 bg-muted/10">
                    <div
                      className={`w-8 h-8 rounded-full ${avatarColor(selected.name)} flex items-center justify-center text-white font-bold text-xs shadow-sm`}
                    >
                      {selected.name.charAt(0).toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-bold text-foreground truncate">{selected.name}</div>
                      {selected.email && (
                        <div className="text-xs text-muted-foreground truncate">{selected.email}</div>
                      )}
                    </div>
                    {selected.room?.lastMessageTime && (
                      <Badge variant="outline" className="font-medium text-xs text-muted-foreground">
                        <Clock className="w-3 h-3 mr-1" />
                        {formatDateTime(selected.room.lastMessageTime)}
                      </Badge>
                    )}
                  </div>
                )}

                {selected && !selected.roomId && (
                  <div className="flex flex-col items-center justify-center flex-1 py-16 text-muted-foreground gap-3 px-6 text-center">
                    <MessageCircleOff className="w-12 h-12 opacity-30" />
                    <p className="font-semibold">Chat not started yet</p>
                    <p className="text-sm max-w-md">
                      A 1:1 chat room is created when the driver pays the communication fee and opens the chat with this passenger.
                    </p>
                  </div>
                )}

                {selected?.roomId && msgsLoading && (
                  <div className="flex items-center justify-center flex-1 py-16">
                    <Loader2 className="w-8 h-8 animate-spin text-primary" />
                  </div>
                )}

                {selected?.roomId && !msgsLoading && messages.length === 0 && (
                  <div className="flex flex-col items-center justify-center flex-1 py-16 text-muted-foreground gap-3">
                    <MessageSquare className="w-12 h-12 opacity-30" />
                    <p className="font-semibold">No messages yet</p>
                  </div>
                )}

                {selected?.roomId && !msgsLoading && messages.length > 0 && (
                  <>
                    <ScrollArea className="flex-1 h-[420px]">
                      <div className="px-6 py-4 space-y-2">
                        {grouped.map(({ msg, isFirst }) => (
                          <MessageBubble
                            key={(msg as unknown as { _id?: string; id?: string })._id || (msg as unknown as { id?: string }).id || `${msg.senderId}-${msg.createdAt}`}
                            msg={msg}
                            isFirst={isFirst}
                          />
                        ))}
                      </div>
                    </ScrollArea>

                    {messagesData?.meta && messagesData.meta.totalPages > 1 && (
                      <div className="flex items-center justify-between px-6 py-3 border-t border-border/30 bg-muted/20">
                        <span className="text-xs text-muted-foreground font-medium">
                          Page {msgPage} of {messagesData.meta.totalPages} · {messagesData.meta.total} messages total
                        </span>
                        <div className="flex gap-2">
                          <Button
                            variant="outline"
                            size="sm"
                            disabled={msgPage <= 1 || isFetching}
                            onClick={() => setMsgPage((p) => p - 1)}
                            className="text-xs"
                          >
                            Older
                          </Button>
                          <Button
                            variant="outline"
                            size="sm"
                            disabled={msgPage >= messagesData.meta.totalPages || isFetching}
                            onClick={() => setMsgPage((p) => p + 1)}
                            className="text-xs"
                          >
                            Newer
                          </Button>
                        </div>
                      </div>
                    )}
                  </>
                )}
              </div>
            </div>
          )}
        </CardContent>
      )}
    </Card>
  )
}
