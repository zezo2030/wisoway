// Bookings List Page: Admin booking management
// Displays all bookings with filters and cancel action

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getBookings, cancelBooking } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL, BOOKING_STATUS_LABELS } from "@/lib/constants"
import { formatDate } from "@/lib/utils"
import type { Booking, UserSummary, TripSummary } from "@/types/models"
import { BookOpen, XCircle, AlertCircle } from "lucide-react"
import { toast } from "sonner"

function isPopulatedUser(val: string | UserSummary): val is UserSummary {
    return typeof val === "object" && val !== null && "name" in val
}

function isPopulatedTrip(val: string | TripSummary): val is TripSummary {
    return typeof val === "object" && val !== null && "from" in val
}

export default function BookingsListPage() {
    const [searchParams, setSearchParams] = useSearchParams()
    const queryClient = useQueryClient()
    const page = parseInt(searchParams.get("page") || "1", 10)
    const status = searchParams.get("status") || undefined
    const limit = 20

    const [confirmDialog, setConfirmDialog] = useState<{
        open: boolean
        booking: Booking | null
    }>({
        open: false,
        booking: null,
    })

    const { data, isLoading, error } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.BOOKINGS, { page, limit, status }],
        queryFn: () => getBookings({ page, limit, status: status as any }),
        refetchInterval: DASHBOARD_REFRESH_INTERVAL,
    })

    const cancelMutation = useMutation({
        mutationFn: (bookingId: string) => cancelBooking(bookingId),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.BOOKINGS] })
            queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS] })
            toast.success("Booking cancelled successfully")
            setConfirmDialog({ open: false, booking: null })
        },
        onError: () => {
            toast.error("Failed to cancel booking")
        },
    })

    const handlePageChange = (newPage: number) => {
        const newParams = new URLSearchParams(searchParams)
        newParams.set("page", String(newPage))
        setSearchParams(newParams)
    }

    const handleStatusFilter = (value: string) => {
        const newParams = new URLSearchParams(searchParams)
        if (value === "all") {
            newParams.delete("status")
        } else {
            newParams.set("status", value)
        }
        newParams.set("page", "1")
        setSearchParams(newParams)
    }

    const columns: Column<Booking>[] = [
        {
            key: "user",
            header: "Passenger",
            cell: (booking) => (
                <div className="flex items-center gap-3 py-1">
                    {isPopulatedUser(booking.userId) ? (
                        <>
                            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20 flex-shrink-0">
                                {booking.userId.name.charAt(0).toUpperCase()}
                            </div>
                            <div>
                                <div className="font-semibold text-foreground">{booking.userId.name}</div>
                                <div className="text-xs font-medium text-muted-foreground">{booking.userId.email}</div>
                            </div>
                        </>
                    ) : (
                        <span className="text-muted-foreground font-mono text-xs">ID: {booking.userId}</span>
                    )}
                </div>
            ),
        },
        {
            key: "trip",
            header: "Trip",
            cell: (booking) => (
                <div className="flex flex-col gap-0.5">
                    {isPopulatedTrip(booking.tripId) ? (
                        <>
                            <div className="font-semibold text-foreground text-sm">{booking.tripId.from?.name} → {booking.tripId.to?.name}</div>
                            <div className="text-xs font-medium text-muted-foreground">{formatDate(booking.tripId.departureTime)}</div>
                        </>
                    ) : (
                        <span className="text-muted-foreground font-mono text-xs">ID: {booking.tripId}</span>
                    )}
                </div>
            ),
        },
        {
            key: "seat",
            header: "Seat",
            cell: (booking) => (
                <div className="font-mono font-bold tracking-wider text-sm bg-muted/60 px-2.5 py-1 rounded w-fit border border-border/40 text-foreground">
                    #{booking.seatNumber}
                </div>
            ),
        },
        {
            key: "status",
            header: "Status",
            cell: (booking) => (
                <StatusBadge
                    status={booking.status === "pending" ? "pending_booking" : booking.status === "confirmed" ? "confirmed" : booking.status === "cancelled" ? "cancelled_booking" : "completed_booking"}
                    type="booking"
                    className="shadow-sm"
                />
            ),
        },
        {
            key: "created",
            header: "Created",
            cell: (booking) => <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">{formatDate(booking.createdAt)}</div>,
        },
        {
            key: "actions",
            header: "Actions",
            className: "w-[120px]",
            cell: (booking) => (
                <div onClick={(e) => e.stopPropagation()}>
                    {(booking.status === "pending" || booking.status === "confirmed") && (
                        <Button
                            size="sm"
                            variant="destructive"
                            className="font-semibold text-xs shadow-sm"
                            onClick={() => setConfirmDialog({ open: true, booking })}
                            disabled={cancelMutation.isPending}
                        >
                            <XCircle className="mr-1.5 h-3.5 w-3.5" />
                            Cancel
                        </Button>
                    )}
                </div>
            ),
        },
    ]

    if (error) {
        return (
            <div className="space-y-4 animate-in fade-in duration-500">
                <h1 className="text-4xl font-extrabold tracking-tight">Bookings</h1>
                <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
                    <AlertCircle className="w-6 h-6 mr-3" />
                    <span className="font-semibold text-lg">Failed to load bookings. Please try again.</span>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
            <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
                <div className="flex items-center gap-4">
                    <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
                        <BookOpen className="w-8 h-8 text-primary" />
                    </div>
                    <div>
                        <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">Bookings</h1>
                        <p className="text-muted-foreground mt-1 text-lg font-medium">
                            Manage and monitor all ride bookings across the platform.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
                <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
                    <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
                        <h2 className="text-xl font-bold flex items-center">
                            <BookOpen className="w-5 h-5 mr-3 text-primary" />
                            All Bookings
                        </h2>
                        <div className="flex items-center gap-3">
                            <Select value={status || "all"} onValueChange={handleStatusFilter}>
                                <SelectTrigger className="w-[160px]">
                                    <SelectValue placeholder="Filter by status" />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="all">All Statuses</SelectItem>
                                    {Object.entries(BOOKING_STATUS_LABELS).map(([key, label]) => (
                                        <SelectItem key={key} value={key}>{label}</SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                            <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                                <span className="text-muted-foreground">Total:</span> <span className="text-foreground ml-1">{data?.meta?.total || 0}</span>
                            </div>
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
                            emptyMessage="No bookings found."
                        />
                    </div>
                </CardContent>
            </Card>

            <ConfirmDialog
                open={confirmDialog.open}
                onOpenChange={(open) => setConfirmDialog((prev) => ({ ...prev, open }))}
                title="Cancel Booking"
                description="Are you sure you want to cancel this booking? The passenger will be notified."
                variant="destructive"
                onConfirm={() => {
                    if (confirmDialog.booking) {
                        cancelMutation.mutate(confirmDialog.booking._id)
                    }
                }}
                loading={cancelMutation.isPending}
            />
        </div>
    )
}
