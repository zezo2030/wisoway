import { useState, useEffect, useMemo, useRef } from "react"
import { useMutation, useQuery } from "@tanstack/react-query"
import {
  createFine,
  getUsers,
  getTrips,
  getBookings,
  getUserById,
} from "@/api/admin"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Gavel, ChevronsUpDown, X } from "lucide-react"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatPhone, getTripLocationName, cn } from "@/lib/utils"
import { UserRole } from "@/types/enums"
import type { TranslationKey } from "@/i18n/translations"
import type { Booking, Trip, User } from "@/types/models"

const NONE = "__none__"

/** Admin PG users use `id`; legacy shape uses `_id`. */
function userEntityId(user: User): string {
  const u = user as User & { id?: string }
  const c = u._id ?? u.id
  return typeof c === "string" && c.trim().length > 0 ? c : ""
}

function tripEntityId(trip: Trip): string {
  const c = (trip as Trip & { id?: string })._id ?? (trip as Trip & { id?: string }).id
  return typeof c === "string" && c.trim().length > 0 ? c : ""
}

function bookingEntityId(booking: Booking): string {
  const c = (booking as Booking & { id?: string })._id ?? (booking as Booking & { id?: string }).id
  return typeof c === "string" && c.trim().length > 0 ? c : ""
}

function bookingTripEntityId(booking: Booking): string {
  const t = booking.tripId
  if (typeof t === "string") return t
  if (t && typeof t === "object") {
    const o = t as { _id?: string; id?: string }
    return o._id ?? o.id ?? ""
  }
  return ""
}

function passengerName(booking: Booking): string {
  if (typeof booking.userId === "object" && booking.userId !== null && "name" in booking.userId) {
    return (booking.userId as { name?: string }).name ?? "—"
  }
  return booking.user?.name ?? "—"
}

function bookingStatusLabel(status: string, t: (k: TranslationKey) => string): string {
  const map: Record<string, TranslationKey> = {
    pending: "pending",
    confirmed: "confirmed",
    cancelled: "cancelled",
    completed: "completed",
    rejected: "rejected",
    no_show: "no_show",
  }
  const key = map[status]
  return key ? t(key) : status
}

interface CreateFineDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  onCreated: () => void
  /** Optional prefill — e.g. when launched from a complaint. */
  driverId?: string
  tripId?: string
  bookingId?: string
}

export function CreateFineDialog({
  open,
  onOpenChange,
  onCreated,
  driverId: initialDriverId,
  tripId: initialTripId,
  bookingId: initialBookingId,
}: CreateFineDialogProps) {
  const { t } = useLanguage()
  const userClearedDriverRef = useRef(false)
  const [selectedDriver, setSelectedDriver] = useState<{
    id: string
    name: string
    phone?: string | null
  } | null>(null)
  const [driverPickerOpen, setDriverPickerOpen] = useState(false)
  const [driverSearchInput, setDriverSearchInput] = useState("")
  const [debouncedDriverSearch, setDebouncedDriverSearch] = useState("")

  const [amount, setAmount] = useState("")
  const [reason, setReason] = useState("")
  const [tripId, setTripId] = useState("")
  const [bookingId, setBookingId] = useState("")

  useEffect(() => {
    if (!open) {
      userClearedDriverRef.current = false
      setSelectedDriver(null)
      setDriverPickerOpen(false)
      setDriverSearchInput("")
      setDebouncedDriverSearch("")
      setAmount("")
      setReason("")
      setTripId("")
      setBookingId("")
    }
  }, [open])

  useEffect(() => {
    if (!open) return
    setTripId(initialTripId ?? "")
    setBookingId(initialBookingId ?? "")
  }, [open, initialTripId, initialBookingId])

  useEffect(() => {
    const id = setTimeout(() => setDebouncedDriverSearch(driverSearchInput), 250)
    return () => clearTimeout(id)
  }, [driverSearchInput])

  const { data: bootstrapUser } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USER, "fine-dialog", initialDriverId],
    queryFn: () => getUserById(initialDriverId!),
    enabled: open && !!initialDriverId && /^[0-9a-f-]{36}$/i.test(initialDriverId.trim()),
  })

  useEffect(() => {
    if (!open || userClearedDriverRef.current || !bootstrapUser || !initialDriverId) return
    const uid = userEntityId(bootstrapUser)
    if (uid !== initialDriverId.trim()) return
    setSelectedDriver({
      id: uid,
      name: bootstrapUser.name,
      phone: bootstrapUser.phoneNumber,
    })
  }, [open, bootstrapUser, initialDriverId])

  const { data: driverSearchResults, isFetching: driversLoading } = useQuery({
    queryKey: [
      QUERY_KEYS.ADMIN.USERS,
      "fine-driver-search",
      debouncedDriverSearch,
    ],
    queryFn: () =>
      getUsers({
        role: UserRole.DRIVER,
        page: 1,
        limit: 30,
        ...(debouncedDriverSearch.trim().length >= 1
          ? { search: debouncedDriverSearch.trim() }
          : {}),
      }),
    enabled: open && driverPickerOpen,
  })

  const driverIdForQueries = selectedDriver?.id ?? ""

  const { data: tripsPage, isFetching: tripsLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIPS, "fine-dialog", driverIdForQueries],
    queryFn: () =>
      getTrips({
        driverId: driverIdForQueries,
        page: 1,
        limit: 100,
      }),
    enabled: open && driverIdForQueries.length > 0,
  })

  const { data: bookingsPage, isFetching: bookingsLoading } = useQuery({
    queryKey: [
      QUERY_KEYS.ADMIN.BOOKINGS,
      "fine-dialog",
      driverIdForQueries,
      tripId || "all",
    ],
    queryFn: () =>
      getBookings({
        driverId: driverIdForQueries,
        page: 1,
        limit: 100,
        ...(tripId.trim().length > 0 ? { tripId: tripId.trim() } : {}),
      }),
    enabled: open && driverIdForQueries.length > 0,
  })

  const trips = tripsPage?.data ?? []
  const bookings = bookingsPage?.data ?? []

  const bookingIdsInList = useMemo(
    () => new Set(bookings.map((b) => bookingEntityId(b)).filter(Boolean)),
    [bookings],
  )

  useEffect(() => {
    if (!bookingId) return
    if (!bookingIdsInList.has(bookingId)) {
      setBookingId("")
    }
  }, [bookingId, bookingIdsInList])

  const mutation = useMutation({
    mutationFn: () =>
      createFine({
        driverId: selectedDriver!.id,
        amount: Number(amount),
        reason: reason.trim(),
        tripId: tripId.trim() || undefined,
        bookingId: bookingId.trim() || undefined,
      }),
    onSuccess: () => {
      onCreated()
    },
    onError: (err: unknown) => {
      const msg =
        (err as { response?: { data?: { message?: string } } }).response?.data
          ?.message ?? t("fineCreateFailed")
      toast.error(typeof msg === "string" ? msg : t("fineCreateFailed"))
    },
  })

  const canSubmit =
    !!selectedDriver?.id &&
    reason.trim().length > 0 &&
    Number(amount) > 0 &&
    !mutation.isPending

  const pickDriver = (u: User) => {
    userClearedDriverRef.current = false
    const id = userEntityId(u)
    if (!id) return
    setSelectedDriver({
      id,
      name: u.name,
      phone: u.phoneNumber,
    })
    setDriverPickerOpen(false)
    setDriverSearchInput("")
    setTripId("")
    setBookingId("")
  }

  const clearDriver = () => {
    userClearedDriverRef.current = true
    setSelectedDriver(null)
    setTripId("")
    setBookingId("")
  }

  const tripLabel = (trip: Trip) => {
    const tr = trip as unknown as Record<string, unknown>
    const from = getTripLocationName(tr, "from")
    const to = getTripLocationName(tr, "to")
    const dep = formatDate(trip.departureTime)
    return `${from} → ${to} · ${dep}`
  }

  const bookingLabel = (b: Booking) => {
    const p = passengerName(b)
    const st = bookingStatusLabel(b.status, t)
    const amt =
      b.totalAmount != null ? Number(b.totalAmount).toFixed(2) : "—"
    return `${p} · ${st} · ${amt}`
  }

  const onTripSelect = (value: string) => {
    const next = value === NONE ? "" : value
    setTripId(next)
    setBookingId("")
  }

  const onBookingSelect = (value: string) => {
    const next = value === NONE ? "" : value
    setBookingId(next)
    if (next) {
      const b = bookings.find((x) => bookingEntityId(x) === next)
      const tid = b ? bookingTripEntityId(b) : ""
      if (tid && tid !== tripId) {
        setTripId(tid)
      }
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Gavel className="h-5 w-5 text-rose-500" />
            {t("createFine")}
          </DialogTitle>
          <DialogDescription>{t("finesSubtitle")}</DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-1.5">
            <Label>{t("fineDriver")}</Label>
            {selectedDriver ? (
              <div className="flex items-center gap-2 rounded-md border bg-muted/40 px-3 py-2">
                <div className="flex min-w-0 flex-1 flex-col">
                  <span className="truncate font-medium">{selectedDriver.name}</span>
                  {selectedDriver.phone ? (
                    <span className="truncate text-xs text-muted-foreground" dir="ltr">
                      {formatPhone(selectedDriver.phone)}
                    </span>
                  ) : null}
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="shrink-0"
                  onClick={clearDriver}
                  title={t("delete")}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>
            ) : null}
            <Popover open={driverPickerOpen} onOpenChange={setDriverPickerOpen}>
              <PopoverTrigger asChild>
                <Button
                  type="button"
                  variant="outline"
                  role="combobox"
                  aria-expanded={driverPickerOpen}
                  className={cn("w-full justify-between font-normal", selectedDriver && "mt-2")}
                >
                  <span className="truncate">
                    {selectedDriver ? t("fineChangeDriver") : t("finePickDriver")}
                  </span>
                  <ChevronsUpDown className="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-[var(--radix-popover-trigger-width)] p-0" align="start">
                <div className="border-b p-2">
                  <Input
                    placeholder={t("fineDriverSearchPlaceholder")}
                    value={driverSearchInput}
                    onChange={(e) => setDriverSearchInput(e.target.value)}
                    className="h-9"
                  />
                </div>
                <ScrollArea className="h-[min(280px,40vh)]">
                  <div className="p-1">
                    {driversLoading ? (
                      <div className="px-2 py-6 text-center text-sm text-muted-foreground">
                        {t("loading")}
                      </div>
                    ) : (driverSearchResults?.data?.length ?? 0) === 0 ? (
                      <div className="px-2 py-6 text-center text-sm text-muted-foreground">
                        {t("fineNoDriversFound")}
                      </div>
                    ) : (
                      driverSearchResults!.data.map((u) => (
                        <button
                          key={userEntityId(u) || u.name}
                          type="button"
                          className="flex w-full flex-col rounded-sm px-2 py-2 text-left text-sm hover:bg-accent"
                          onClick={() => pickDriver(u)}
                        >
                          <span className="font-medium">{u.name}</span>
                          {u.phoneNumber ? (
                            <span className="text-xs text-muted-foreground" dir="ltr">
                              {formatPhone(u.phoneNumber)}
                            </span>
                          ) : null}
                        </button>
                      ))
                    )}
                  </div>
                </ScrollArea>
              </PopoverContent>
            </Popover>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="fine-amount">{t("fineAmount")}</Label>
            <Input
              id="fine-amount"
              type="number"
              min="0"
              step="0.01"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              dir="ltr"
            />
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="fine-reason">{t("fineReason")}</Label>
            <Textarea
              id="fine-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder={t("fineReasonPlaceholder")}
              rows={3}
              maxLength={2000}
            />
          </div>

          <p className="text-sm text-muted-foreground leading-relaxed border-t pt-3">
            {t("fineTripBookingHint")}
          </p>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="fine-trip">{t("fineTripId")}</Label>
              <Select
                value={tripId ? tripId : NONE}
                onValueChange={onTripSelect}
                disabled={!selectedDriver || tripsLoading}
              >
                <SelectTrigger id="fine-trip" className="w-full">
                  <SelectValue placeholder={t("fineChooseTrip")} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>{t("fineNoneOption")}</SelectItem>
                  {trips.map((trip) => {
                    const id = tripEntityId(trip)
                    if (!id) return null
                    return (
                      <SelectItem key={id} value={id}>
                        <span className="line-clamp-2">{tripLabel(trip)}</span>
                      </SelectItem>
                    )
                  })}
                </SelectContent>
              </Select>
              {trips.length === 0 && selectedDriver && !tripsLoading ? (
                <p className="text-xs text-muted-foreground">{t("fineNoTripsForDriver")}</p>
              ) : null}
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="fine-booking">{t("fineBookingId")}</Label>
              <Select
                value={bookingId ? bookingId : NONE}
                onValueChange={onBookingSelect}
                disabled={!selectedDriver || bookingsLoading}
              >
                <SelectTrigger id="fine-booking" className="w-full">
                  <SelectValue placeholder={t("fineChooseBooking")} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={NONE}>{t("fineNoneOption")}</SelectItem>
                  {bookings.map((b) => {
                    const id = bookingEntityId(b)
                    if (!id) return null
                    return (
                      <SelectItem key={id} value={id}>
                        <span className="line-clamp-2">{bookingLabel(b)}</span>
                      </SelectItem>
                    )
                  })}
                </SelectContent>
              </Select>
              {bookings.length === 0 && selectedDriver && !bookingsLoading ? (
                <p className="text-xs text-muted-foreground">{t("fineNoBookingsForDriver")}</p>
              ) : null}
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" type="button" onClick={() => onOpenChange(false)}>
            {t("cancel")}
          </Button>
          <Button type="button" onClick={() => mutation.mutate()} disabled={!canSubmit}>
            {mutation.isPending ? "..." : t("createFine")}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
