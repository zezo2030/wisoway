import { useEffect, useMemo, useRef, useState } from "react"
import { Link, useNavigate, useParams } from "react-router-dom"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { io, type Socket } from "socket.io-client"
import {
  ArrowLeft,
  Loader2,
  MessageCircleOff,
  MessageSquare,
  User,
  Wifi,
  WifiOff,
} from "lucide-react"

import { getDashboardChatMessages, getChatRoomsForTrip, getBookingsForTrip, getTripById } from "@/api/admin"
import { getAccessToken } from "@/api/client"
import { Button } from "@/components/ui/button"
import { Card, CardTitle } from "@/components/ui/card"
import { ScrollArea } from "@/components/ui/scroll-area"
import { API_BASE_URL, QUERY_KEYS } from "@/lib/constants"
import { cn, formatDateTime, getTripLocationName } from "@/lib/utils"
import type { Booking, ChatMessage, ChatRoom, Trip, UserSummary } from "@/types/models"

const SOCKET_URL = API_BASE_URL.replace(/\/api\/v1\/?$/, "")
const MESSAGE_PAGE_SIZE = 100
const MESSAGE_MAX_PAGES = 25

// helpers

function getRoomId(room: ChatRoom): string {
  return (room as unknown as { id?: string }).id || room._id || ""
}

function getDriverId(trip: Trip | undefined): string | null {
  if (!trip) return null
  if (typeof trip.driverId === "string") return trip.driverId
  const d = trip.driverId as UserSummary
  return d?._id ?? null
}

function getUserId(value: string | UserSummary): string {
  if (typeof value === "string") return value
  return value._id
}

function getMessageKey(msg: ChatMessage): string {
  const m = msg as unknown as { id?: string }
  return m.id || msg._id || `${msg.senderId}-${msg.createdAt}-${msg.text}`
}

function getSortedUniqueMessages(messages: ChatMessage[]): ChatMessage[] {
  const map = new Map<string, ChatMessage>()
  for (const msg of messages) map.set(getMessageKey(msg), msg)
  return [...map.values()].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  )
}

async function loadAllMessages(roomId: string): Promise<ChatMessage[]> {
  let page = 1
  let totalPages = 1
  const all: ChatMessage[] = []
  while (page <= totalPages && page <= MESSAGE_MAX_PAGES) {
    const res = await getDashboardChatMessages(roomId, { page, limit: MESSAGE_PAGE_SIZE })
    all.push(...(res.data ?? []))
    totalPages = Math.max(res.meta?.totalPages ?? 1, 1)
    page += 1
  }
  return getSortedUniqueMessages(all)
}

function buildPassengerMap(bookings: Booking[]): Map<string, string> {
  const map = new Map<string, string>()
  for (const b of bookings) {
    const uid = getUserId(b.userId)
    if (typeof b.userId === "object" && b.userId !== null) {
      map.set(uid, (b.userId as UserSummary).name || uid)
    } else {
      map.set(uid, uid)
    }
  }
  return map
}

// Room sidebar item

function RoomItem({
  room,
  passengerName,
  selected,
  onClick,
}: {
  room: ChatRoom
  passengerName: string
  selected: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "w-full flex items-start gap-3 rounded-xl px-3 py-3 text-left transition-colors",
        selected
          ? "bg-primary/10 border border-primary/30"
          : "hover:bg-muted/50 border border-transparent",
      )}
    >
      <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted border border-border/50">
        <User className="h-4 w-4 text-muted-foreground" />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between gap-1">
          <span className="truncate text-sm font-semibold">{passengerName}</span>
          {room.lastMessageTime && (
            <span className="shrink-0 text-[10px] text-muted-foreground">
              {new Date(room.lastMessageTime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
            </span>
          )}
        </div>
        {room.lastMessage && (
          <p className="mt-0.5 truncate text-xs text-muted-foreground">{room.lastMessage}</p>
        )}
      </div>
    </button>
  )
}

// Message bubble

function MessageBubble({ msg, isDriver }: { msg: ChatMessage; isDriver: boolean }) {
  return (
    <div className={cn("flex", isDriver ? "justify-end" : "justify-start")}>
      <div
        className={cn(
          "max-w-[80%] rounded-2xl px-4 py-3 shadow-sm",
          isDriver
            ? "bg-primary text-primary-foreground rounded-br-md"
            : "bg-muted border border-border/40 rounded-bl-md",
        )}
      >
        <div
          className={cn(
            "mb-1 text-xs font-bold",
            isDriver ? "text-primary-foreground/80" : "text-foreground",
          )}
        >
          {msg.senderName}&nbsp;
          <span className="font-normal opacity-70">{isDriver ? "(Driver)" : "(Passenger)"}</span>
        </div>
        <p className={cn("text-sm leading-relaxed whitespace-pre-wrap", isDriver ? "text-primary-foreground" : "text-foreground")}>
          {msg.text}
        </p>
        <div className={cn("mt-1 text-[10px]", isDriver ? "text-primary-foreground/60" : "text-muted-foreground")}>
          {formatDateTime(msg.createdAt)}
        </div>
      </div>
    </div>
  )
}

// Chat panel (right side)

function ChatPanel({
  room,
  driverId,
  passengerName,
}: {
  room: ChatRoom
  driverId: string | null
  passengerName: string
}) {
  const queryClient = useQueryClient()
  const bottomRef = useRef<HTMLDivElement | null>(null)
  const socketRef = useRef<Socket | null>(null)
  const [connected, setConnected] = useState(false)
  const roomId = getRoomId(room)

  const { data: messages = [], isLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.CHAT_MESSAGES, "dashboard", roomId],
    queryFn: () => loadAllMessages(roomId),
    enabled: !!roomId,
  })

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth", block: "end" })
  }, [messages.length])

  useEffect(() => {
    if (!roomId) return
    const token = getAccessToken()
    const socket = io(`${SOCKET_URL}/chat`, {
      auth: { token },
      extraHeaders: token ? { Authorization: `Bearer ${token}` } : {},
      transports: ["websocket", "polling"],
    })
    socketRef.current = socket

    socket.on("connect", () => {
      setConnected(true)
      socket.emit("joinRoom", { chatRoomId: roomId })
    })
    socket.on("disconnect", () => setConnected(false))
    socket.on("connect_error", () => setConnected(false))

    socket.on("newMessage", (msg: ChatMessage) => {
      queryClient.setQueryData<ChatMessage[]>(
        [QUERY_KEYS.ADMIN.CHAT_MESSAGES, "dashboard", roomId],
        (prev = []) => getSortedUniqueMessages([...prev, msg]),
      )
    })

    return () => {
      socket.emit("leaveRoom", { chatRoomId: roomId })
      socket.disconnect()
      socketRef.current = null
      setConnected(false)
    }
  }, [roomId, queryClient])

  return (
    <div className="flex h-full flex-col">
      <div className="flex items-center justify-between border-b border-border/40 bg-muted/20 px-4 py-3">
        <div className="flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-muted border border-border/50">
            <User className="h-4 w-4 text-muted-foreground" />
          </div>
          <div>
            <p className="text-sm font-semibold leading-none">{passengerName}</p>
            <p className="mt-0.5 text-xs text-muted-foreground">Driver ↔ Passenger chat</p>
          </div>
        </div>
        <div
          className={cn(
            "flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-semibold",
            connected
              ? "border-green-500/40 bg-green-500/10 text-green-600"
              : "border-muted text-muted-foreground",
          )}
        >
          {connected ? <Wifi className="h-3 w-3" /> : <WifiOff className="h-3 w-3" />}
          {connected ? "Live" : "Connecting…"}
        </div>
      </div>

      {isLoading ? (
        <div className="flex flex-1 items-center justify-center">
          <Loader2 className="h-7 w-7 animate-spin text-primary" />
        </div>
      ) : messages.length === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center gap-2 text-muted-foreground">
          <MessageSquare className="h-10 w-10 opacity-30" />
          <p className="text-sm font-medium">No messages yet</p>
        </div>
      ) : (
        <ScrollArea className="flex-1">
          <div className="space-y-3 p-4">
            {messages.map((msg) => (
              <MessageBubble
                key={getMessageKey(msg)}
                msg={msg}
                isDriver={!!driverId && msg.senderId === driverId}
              />
            ))}
            <div ref={bottomRef} />
          </div>
        </ScrollArea>
      )}
    </div>
  )
}

// Page

export default function TripChatLivePage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [selectedRoomId, setSelectedRoomId] = useState<string | null>(null)

  const { data: trip, isLoading: tripLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIP, id],
    queryFn: () => getTripById(id!),
    enabled: !!id,
  })

  const { data: roomsPage, isLoading: roomsLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.CHAT_ROOMS, "forTrip", id],
    queryFn: () => getChatRoomsForTrip(id!),
    enabled: !!id,
  })

  const { data: bookingsPage } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.BOOKINGS, "forTrip", id],
    queryFn: () => getBookingsForTrip(id!),
    enabled: !!id,
  })

  const rooms: ChatRoom[] = roomsPage?.data ?? []
  const passengerMap = useMemo(() => buildPassengerMap(bookingsPage?.data ?? []), [bookingsPage])
  const driverId = useMemo(() => getDriverId(trip), [trip])

  useEffect(() => {
    if (rooms.length > 0 && !selectedRoomId) {
      setSelectedRoomId(getRoomId(rooms[0]))
    }
  }, [rooms, selectedRoomId])

  const selectedRoom = rooms.find((r) => getRoomId(r) === selectedRoomId) ?? null
  const fromName = trip ? getTripLocationName(trip as unknown as Record<string, unknown>, "from") : "…"
  const toName = trip ? getTripLocationName(trip as unknown as Record<string, unknown>, "to") : "…"

  if (tripLoading) {
    return (
      <div className="space-y-4 animate-in fade-in duration-300">
        <div className="h-10 w-48 rounded-xl bg-muted/60 animate-pulse" />
        <div className="h-[80vh] rounded-2xl bg-muted/60 animate-pulse" />
      </div>
    )
  }

  return (
    <div className="flex h-[calc(100vh-5rem)] flex-col gap-4 animate-in fade-in duration-300">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" className="rounded-full" onClick={() => navigate(-1)}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <div>
          <h1 className="text-xl font-black tracking-tight">Trip Chat</h1>
          <p className="text-xs text-muted-foreground font-medium">
            {fromName} → {toName}
          </p>
        </div>
        <div className="ml-auto">
          <Button asChild variant="outline" size="sm" className="rounded-full">
            <Link to={`/trips/${id}`}>Back to Trip</Link>
          </Button>
        </div>
      </div>

      <Card className="flex-1 overflow-hidden border-border/50 shadow-lg bg-card/70 backdrop-blur-xl">
        <div className="flex h-full">
          {/* Left sidebar */}
          <div className="flex w-72 shrink-0 flex-col border-r border-border/40">
            <div className="border-b border-border/40 px-4 py-3">
              <CardTitle className="flex items-center gap-2 text-sm">
                <MessageSquare className="h-4 w-4 text-cyan-500" />
                Passengers
                <span className="ml-auto rounded-full bg-muted px-2 py-0.5 text-xs font-semibold text-muted-foreground">
                  {rooms.length}
                </span>
              </CardTitle>
            </div>
            <ScrollArea className="flex-1">
              {roomsLoading ? (
                <div className="flex h-40 items-center justify-center">
                  <Loader2 className="h-6 w-6 animate-spin text-primary" />
                </div>
              ) : rooms.length === 0 ? (
                <div className="flex h-40 flex-col items-center justify-center gap-2 px-4 text-muted-foreground">
                  <MessageCircleOff className="h-8 w-8 opacity-30" />
                  <p className="text-center text-xs">No chat rooms for this trip yet</p>
                </div>
              ) : (
                <div className="space-y-1 p-2">
                  {rooms.map((room) => {
                    const rid = getRoomId(room)
                    const pid = room.passengerId ?? ""
                    const name = passengerMap.get(pid) || `Passenger (${pid.slice(0, 6)}…)`
                    return (
                      <RoomItem
                        key={rid}
                        room={room}
                        passengerName={name}
                        selected={rid === selectedRoomId}
                        onClick={() => setSelectedRoomId(rid)}
                      />
                    )
                  })}
                </div>
              )}
            </ScrollArea>
          </div>

          {/* Right panel */}
          <div className="flex flex-1 flex-col overflow-hidden">
            {selectedRoom ? (
              <ChatPanel
                key={getRoomId(selectedRoom)}
                room={selectedRoom}
                driverId={driverId}
                passengerName={
                  passengerMap.get(selectedRoom.passengerId ?? "") ||
                  `Passenger (${(selectedRoom.passengerId ?? "").slice(0, 6)}…)`
                }
              />
            ) : (
              <div className="flex flex-1 flex-col items-center justify-center gap-3 text-muted-foreground">
                <MessageSquare className="h-12 w-12 opacity-20" />
                <p className="text-sm font-medium">Select a passenger to view chat</p>
              </div>
            )}
          </div>
        </div>
      </Card>
    </div>
  )
}
