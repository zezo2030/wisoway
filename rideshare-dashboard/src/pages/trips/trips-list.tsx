// Trips List Page: Trip monitoring with filters
// T031: Implements trips list with DataTable and filters

import { useSearchParams, useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getTrips } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatCurrency, getTripLocationName } from "@/lib/utils"
import { TripStatus } from "@/types/enums"
import type { Trip, UserSummary } from "@/types/models"
import { Car, Navigation, Filter, MapPin, Calendar, Users, DollarSign, ArrowLeftRight } from "lucide-react"

// Type guard for populated fields
function isPopulatedDriver(driverId: string | UserSummary): driverId is UserSummary {
  return typeof driverId === "object" && driverId !== null && "name" in driverId
}

function getTripId(trip: Trip): string | null {
  const candidate = (trip as Trip & { id?: string })._id ?? (trip as Trip & { id?: string }).id
  return typeof candidate === "string" && candidate.trim().length > 0 ? candidate : null
}

function getDriverName(driverId: string | UserSummary): string | null {
  if (!isPopulatedDriver(driverId)) {
    return null
  }
  const name = driverId.name?.trim()
  return name || null
}

export default function TripsListPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = 20
  const statusFilter = searchParams.get("status") || ""

  // Fetch trips
  const { data, isLoading } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIPS, { page, limit, status: statusFilter }],
    queryFn: () =>
      getTrips({
        page,
        limit,
        status: (statusFilter as TripStatus) || undefined,
      }),
  })

  const updateSearchParams = (updates: Record<string, string | null>) => {
    const newParams = new URLSearchParams(searchParams)
    Object.entries(updates).forEach(([key, value]) => {
      if (value === null) {
        newParams.delete(key)
      } else {
        newParams.set(key, value)
      }
    })
    if (Object.keys(updates).some((k) => k !== "page")) {
      newParams.set("page", "1")
    }
    setSearchParams(newParams)
  }

  const handlePageChange = (newPage: number) => {
    updateSearchParams({ page: String(newPage) })
  }

  const handleRowClick = (trip: Trip) => {
    const tripId = getTripId(trip)
    if (!tripId) {
      return
    }
    navigate(`/trips/${tripId}`)
  }

  // Table columns
  const columns: Column<Trip>[] = [
    {
      key: "route",
      header: "Route",
      cell: (trip) => {
        const fromName = getTripLocationName(trip as Record<string, unknown>, "from")
        const toName = getTripLocationName(trip as Record<string, unknown>, "to")
        return (
          <div className="flex items-center gap-2 py-1">
            <div className="bg-primary/10 p-2 rounded-lg border border-primary/20 shadow-inner flex-shrink-0">
              <Navigation className="w-4 h-4 text-primary" />
            </div>
            <div>
              <div className="font-bold text-foreground flex items-center gap-1.5 flex-wrap">
                {fromName} <ArrowLeftRight className="w-3 h-3 text-muted-foreground" /> {toName}
              </div>
            </div>
          </div>
        )
      },
    },
    {
      key: "driver",
      header: "Driver",
      cell: (trip) => {
        const driverName = getDriverName(trip.driverId)
        return (
          <div className="flex items-center gap-2">
            {driverName ? (
              <>
                <div className="flex h-7 w-7 items-center justify-center rounded-full bg-muted text-muted-foreground font-bold text-xs shadow-sm border border-border/40 flex-shrink-0">
                  {driverName.charAt(0).toUpperCase()}
                </div>
                <div className="font-semibold">{driverName}</div>
              </>
            ) : (
              <span className="text-muted-foreground font-mono text-xs">ID: {trip.driverId}</span>
            )}
          </div>
        )
      },
    },
    {
      key: "departure",
      header: "Departure",
      cell: (trip) => (
        <div className="flex items-center text-sm font-medium text-muted-foreground">
          <Calendar className="w-3.5 h-3.5 mr-1.5 opacity-70" />
          {formatDate(trip.departureTime)}
        </div>
      )
    },
    {
      key: "status",
      header: "Status",
      cell: (trip) => <StatusBadge status={trip.status} type="trip" className="shadow-sm" />,
    },
    {
      key: "seats",
      header: "Available Seats",
      cell: (trip) => (
        <div className="flex items-center gap-2">
          <div className="flex items-center bg-muted/60 px-2.5 py-1 rounded-md border border-border/40">
            <Users className="w-3.5 h-3.5 mr-1.5 text-muted-foreground" />
            <span className="font-bold text-foreground">{trip.availableSeats}</span>
            <span className="text-muted-foreground mx-0.5">/</span>
            <span className="font-bold text-muted-foreground">{trip.totalSeats}</span>
          </div>
        </div>
      ),
    },
    {
      key: "price",
      header: "Price",
      cell: (trip) => (
        <div className="font-black text-emerald-600 dark:text-emerald-400 flex items-center">
          {formatCurrency(trip.price, trip.currency)}
        </div>
      ),
    },
    {
      key: "created",
      header: "Created",
      cell: (trip) => <div className="text-sm font-medium text-muted-foreground">{formatDate(trip.createdAt)}</div>,
    },
  ]

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
            <Car className="w-8 h-8 text-primary" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">Trips Overview</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              Monitor, filter, and manage all scheduled and past trips on the platform.
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <div className="flex items-center gap-2">
              <CardTitle className="text-xl font-bold flex items-center">
                <MapPin className="w-5 h-5 mr-2 text-primary" />
                Active Directory
              </CardTitle>
            </div>

            {/* Filters Row */}
            <div className="flex flex-col sm:flex-row w-full sm:w-auto gap-3 items-center">
              <div className="flex items-center text-sm font-semibold text-muted-foreground mr-1">
                <Filter className="w-4 h-4 mr-1.5" /> Filters:
              </div>

              <Select
                value={statusFilter || "all"}
                onValueChange={(value) => updateSearchParams({ status: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-full sm:w-[160px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm">
                  <SelectValue placeholder="All Status" />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">All Status</SelectItem>
                  <SelectItem value={TripStatus.ACTIVE}>Active</SelectItem>
                  <SelectItem value={TripStatus.HIDDEN}>Hidden</SelectItem>
                  <SelectItem value={TripStatus.COMPLETED}>Completed</SelectItem>
                  <SelectItem value={TripStatus.CANCELLED}>Cancelled</SelectItem>
                  <SelectItem value={TripStatus.EXPIRED}>Expired</SelectItem>
                </SelectContent>
              </Select>
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
              emptyMessage="No trips found matching the current criteria."
              onRowClick={handleRowClick}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
