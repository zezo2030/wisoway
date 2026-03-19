// Trip Detail Page: Trip information with seat map
// T032: Implements trip detail view with SeatMap and bookings

import { useParams, useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getTripById, getTripSeats, getBookingsForTrip, getUserById } from "@/api/admin"
import { SeatMap } from "@/components/seat-map"
import { StatusBadge } from "@/components/status-badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { QUERY_KEYS } from "@/lib/constants"
import { formatSeatDisplay } from "@/lib/seat-format"
import { formatDateTime, formatCurrency, cn, getTripLocationName } from "@/lib/utils"
import type { UserSummary } from "@/types/models"
import { ArrowLeft, MapPin, User, Calendar, DollarSign, Car, Users, ArrowLeftRight, Activity, CreditCard, ShieldCheck, Route } from "lucide-react"

// Type guard for populated fields
function isPopulatedDriver(driverId: string | UserSummary): driverId is UserSummary {
  return typeof driverId === "object" && driverId !== null && "name" in driverId
}

export default function TripDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()

  // Fetch trip data
  const { data: trip, isLoading: isLoadingTrip } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIP, id],
    queryFn: () => getTripById(id!),
    enabled: !!id,
  })

  // Fetch trip seats
  const { data: seats } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIP, id, "seats"],
    queryFn: () => getTripSeats(id!),
    enabled: !!id,
  })

  // Fetch bookings for trip
  const { data: bookings } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIP, id, "bookings"],
    queryFn: () => getBookingsForTrip(id!),
    enabled: !!id,
  })

  const driverId = trip && typeof trip.driverId === "string" ? trip.driverId : undefined
  const { data: driverUser } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USER, driverId],
    queryFn: () => getUserById(driverId!),
    enabled: !!driverId,
  })

  if (isLoadingTrip) {
    return (
      <div className="space-y-6 animate-in fade-in duration-500">
        <div className="flex items-center gap-4">
          <div className="h-10 w-24 animate-pulse rounded-full bg-muted/60" />
        </div>
        <div className="h-48 animate-pulse rounded-3xl bg-muted/60" />
        <div className="h-72 animate-pulse rounded-3xl bg-muted/60" />
      </div>
    )
  }

  if (!trip) {
    return (
      <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
        <Button variant="ghost" onClick={() => navigate(-1)} className="rounded-full shadow-sm bg-background border border-border/50">
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Trips
        </Button>
        <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl">
          <CardContent className="flex flex-col items-center justify-center h-[300px] text-muted-foreground">
            <Car className="h-16 w-16 mb-4 text-muted-foreground/30" />
            <h3 className="text-2xl font-bold text-foreground">Trip Not Found</h3>
            <p className="mt-2 text-center text-sm">The trip details you are looking for do not exist or have been removed.</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  const fromName = getTripLocationName(trip as unknown as Record<string, unknown>, "from")
  const toName = getTripLocationName(trip as unknown as Record<string, unknown>, "to")
  const driverDisplayName = isPopulatedDriver(trip.driverId)
    ? trip.driverId.name
    : trip.driverName || driverUser?.name || "Unknown Driver"
  const driverDisplayContact = isPopulatedDriver(trip.driverId)
    ? trip.driverId.email
    : driverUser?.email || "No email provided"

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">

      {/* Header section with sticky property */}
      <div className="flex flex-col md:flex-row gap-4 md:items-center justify-between sticky top-14 z-20 bg-background/80 backdrop-blur-xl py-4 -mx-4 px-4 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8 border-b border-border/40 shadow-sm">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => navigate(-1)} className="rounded-full bg-muted/60 hover:bg-muted border border-border/50 transition-colors hidden sm:flex">
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div className="flex items-center gap-3">
            <div className="bg-primary p-2.5 rounded-xl border border-primary/20 shadow-md">
              <Car className="w-5 h-5 text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-2xl font-black tracking-tight flex items-center gap-2">
                <span>{fromName}</span>
                <ArrowLeftRight className="w-4 h-4 text-muted-foreground" />
                <span>{toName}</span>
              </h1>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3 bg-muted/40 p-1.5 pl-4 rounded-full border border-border/40 w-fit">
          <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Status</span>
          <StatusBadge status={trip.status} type="trip" className="shadow-sm" />
        </div>
      </div>

      <div className="grid gap-6 grid-cols-1 lg:grid-cols-3">
        {/* Analytics & Important stats column */}
        <div className="lg:col-span-1 space-y-6">
          <Card className="border-none shadow-xl bg-gradient-to-br from-card to-muted/20 relative overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full blur-3xl -mr-10 -mt-10 pointer-events-none" />

            <CardHeader className="pb-2 relative z-10">
              <CardTitle className="text-lg font-bold flex items-center">
                <Activity className="h-5 w-5 mr-2 text-primary" /> Core Details
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4 pt-4 relative z-10">
              <div className="flex items-center justify-between bg-emerald-50 dark:bg-emerald-950/20 p-4 rounded-2xl border border-emerald-100 dark:border-emerald-900/40">
                <div>
                  <p className="text-xs font-bold text-emerald-600/70 uppercase tracking-widest mb-1">Ticket Price</p>
                  <p className="font-black text-2xl text-emerald-600 dark:text-emerald-400">
                    {formatCurrency(trip.price, trip.currency)}
                  </p>
                </div>
                <div className="bg-emerald-100 dark:bg-emerald-900/60 p-3 rounded-full text-emerald-600">
                  <DollarSign className="w-6 h-6" />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                {trip.distanceKm != null && (
                  <div className="bg-muted/40 p-4 rounded-2xl border border-border/40 flex flex-col items-center justify-center text-center">
                    <Route className="w-6 h-6 text-muted-foreground/50 mb-2" />
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">Distance</p>
                    <p className="font-bold text-lg text-foreground mt-0.5 whitespace-nowrap">
                      {trip.distanceKm.toFixed(1)} km
                    </p>
                  </div>
                )}
                <div className="bg-muted/40 p-4 rounded-2xl border border-border/40 flex flex-col items-center justify-center text-center">
                  <Users className="w-6 h-6 text-muted-foreground/50 mb-2" />
                  <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">Seats</p>
                  <p className="font-bold text-lg text-foreground mt-0.5 whitespace-nowrap">
                    <span className={trip.availableSeats === 0 ? "text-rose-500" : "text-emerald-500"}>{trip.availableSeats}</span> <span className="text-muted-foreground text-sm font-medium opacity-70"> / {trip.totalSeats}</span>
                  </p>
                </div>

                <div className="bg-muted/40 p-4 rounded-2xl border border-border/40 flex flex-col items-center justify-center text-center">
                  <ShieldCheck className="w-6 h-6 text-muted-foreground/50 mb-2" />
                  <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider truncate w-full px-1">Comm. Fee</p>
                  <p className={cn(
                    "font-bold text-sm mt-0.5 uppercase tracking-wide px-2 py-0.5 rounded border border-border/50",
                    trip.communicationFeeStatus === 'paid' ? "text-emerald-600 bg-emerald-50 dark:bg-emerald-950/30" : "text-amber-600 bg-amber-50 dark:bg-amber-950/30"
                  )}>
                    {trip.communicationFeeStatus}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl">
            <CardHeader className="pb-4">
              <CardTitle className="text-lg font-bold flex items-center">
                <User className="h-5 w-5 mr-2 text-primary" /> Driver Info
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="flex items-center gap-4 bg-muted/30 p-4 rounded-xl border border-border/40">
                <div className="h-12 w-12 rounded-full bg-primary/20 flex flex-shrink-0 items-center justify-center text-primary font-bold shadow-inner">
                  {driverDisplayName.charAt(0).toUpperCase()}
                </div>
                <div>
                  <p className="font-bold text-foreground">
                    {driverDisplayName}
                  </p>
                  <p className="text-sm font-medium text-muted-foreground">
                    {driverDisplayContact}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Detailed scheduling information column */}
        <div className="lg:col-span-2 space-y-6">
          <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl h-full">
            <CardHeader className="border-b border-border/40 pb-4">
              <CardTitle className="text-lg font-bold flex items-center">
                <Calendar className="h-5 w-5 mr-2 text-primary" /> Route & Schedule Planner
              </CardTitle>
            </CardHeader>
            <CardContent className="pt-6">

              <div className="relative pl-6 pb-6 border-l-2 border-primary/30 ml-4 space-y-8">
                <div className="relative">
                  <div className="absolute -left-[35px] top-1 h-6 w-6 rounded-full bg-background border-4 border-primary flex items-center justify-center shadow-sm">
                    <div className="h-1.5 w-1.5 rounded-full bg-primary"></div>
                  </div>
                  <div className="bg-muted/40 p-4 rounded-xl border border-border/40 -mt-2">
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider flex items-center gap-1.5">
                      <MapPin className="w-3.5 h-3.5" /> Departure Location
                    </p>
                    <p className="font-bold text-xl mt-1 text-foreground">{fromName}</p>
                    <p className="text-sm font-medium text-primary mt-2 flex items-center gap-2 bg-primary/5 w-fit px-3 py-1.5 rounded-md border border-primary/20">
                      <Calendar className="w-4 h-4" />
                      {formatDateTime(trip.departureTime)}
                    </p>
                  </div>
                </div>

                <div className="relative">
                  <div className="absolute -left-[35px] top-1 h-6 w-6 rounded-full bg-background border-4 border-emerald-500 flex items-center justify-center shadow-sm">
                    <MapPin className="h-3 w-3 text-emerald-500" />
                  </div>
                  <div className="bg-emerald-500/5 p-4 rounded-xl border border-emerald-500/20 -mt-2">
                    <p className="text-xs font-bold text-emerald-600/70 uppercase tracking-wider flex items-center gap-1.5">
                      <MapPin className="w-3.5 h-3.5" /> Destination
                    </p>
                    <p className="font-bold text-xl mt-1 text-foreground">{toName}</p>
                  </div>
                </div>
              </div>

            </CardContent>
          </Card>
        </div>
      </div>

      <div className="grid gap-6 grid-cols-1 xl:grid-cols-2">
        {/* Bookings Section */}
        <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl overflow-hidden h-fit flex flex-col">
          <CardHeader className="bg-muted/30 border-b border-border/40 pb-4 pt-5">
            <div className="flex items-center justify-between">
              <CardTitle className="text-lg font-bold flex items-center">
                <CreditCard className="w-5 h-5 mr-2 text-primary" /> Active Bookings
              </CardTitle>
              <div className="bg-background px-3 py-1 rounded-full text-xs font-bold shadow-sm border border-border/50">
                <span className="text-muted-foreground">Total:</span> {bookings?.data?.length || 0}
              </div>
            </div>
            <CardDescription className="text-sm font-medium mt-1">Passengers reserving seats for this trip.</CardDescription>
          </CardHeader>
          <CardContent className="p-0">
            {bookings && bookings.data.length > 0 ? (
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader className="bg-muted/10">
                    <TableRow className="hover:bg-transparent">
                      <TableHead className="font-bold">Passenger</TableHead>
                      <TableHead className="font-bold text-center">Seat #</TableHead>
                      <TableHead className="font-bold text-center">Status</TableHead>
                      <TableHead className="font-bold text-right">Payment</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {bookings.data.map((booking) => (
                      <TableRow key={booking._id} className="group hover:bg-muted/30 transition-colors">
                        <TableCell>
                          {typeof booking.userId === "object" && booking.userId !== null ? (
                            <div className="flex items-center gap-3">
                              <div className="bg-primary/10 w-8 h-8 rounded-full flex items-center justify-center text-primary font-bold shadow-sm border border-primary/20 flex-shrink-0 text-xs">
                                {booking.userId.name.charAt(0).toUpperCase()}
                              </div>
                              <div>
                                <div className="font-bold text-sm text-foreground">{booking.userId.name}</div>
                                <div className="text-xs font-medium text-muted-foreground group-hover:text-primary transition-colors">
                                  {booking.userId.email}
                                </div>
                              </div>
                            </div>
                          ) : (
                            <span className="text-muted-foreground font-mono text-xs bg-muted px-2 py-1 rounded">
                              ID: {booking.userId.toString().slice(0, 8)}...
                            </span>
                          )}
                        </TableCell>
                        <TableCell className="text-center">
                          <span
                            className="font-black text-sm bg-muted/60 border border-border/50 px-2.5 py-1 rounded shadow-sm inline-block min-w-[32px]"
                            title={
                              trip.seatLayout?.seatsPerRow
                                ? `Server seat id: ${booking.seatNumber}`
                                : undefined
                            }
                          >
                            #{formatSeatDisplay(booking.seatNumber, trip.seatLayout?.seatsPerRow)}
                          </span>
                        </TableCell>
                        <TableCell className="text-center">
                          <StatusBadge status={booking.status} type="booking" className="shadow-sm" />
                        </TableCell>
                        <TableCell className="text-right">
                          {booking.hasDriverPaidToContact ? (
                            <span className="inline-flex items-center text-xs font-bold text-emerald-600 bg-emerald-50 dark:bg-emerald-950/40 px-2 py-1 rounded border border-emerald-200 dark:border-emerald-800 shadow-sm">
                              Paid
                            </span>
                          ) : (
                            <span className="inline-flex items-center text-xs font-bold text-amber-600 bg-amber-50 dark:bg-amber-950/40 px-2 py-1 rounded border border-amber-200 dark:border-amber-800 shadow-sm">
                              Pending
                            </span>
                          )}
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center p-12 text-center h-full min-h-[250px]">
                <div className="bg-muted p-4 rounded-full mb-4 opacity-50">
                  <User className="h-8 w-8 text-muted-foreground" />
                </div>
                <h3 className="text-lg font-bold">No active bookings</h3>
                <p className="text-muted-foreground text-sm max-w-[250px] mt-1 font-medium">This trip has no passenger reservations yet.</p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Seat Map Section */}
        {trip.seatLayout && seats && (
          <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl flex flex-col">
            <CardHeader className="bg-muted/30 border-b border-border/40 pb-4 pt-5">
              <CardTitle className="text-lg font-bold flex items-center">
                <Users className="w-5 h-5 mr-2 text-primary" /> Visual Seat Layout
              </CardTitle>
              <CardDescription className="text-sm font-medium mt-1">
                Current visual representation of {trip.seatLayout.preventGenderMixing ? "gender-restricted" : "unrestricted"} seats.
              </CardDescription>
            </CardHeader>
            <CardContent className="pt-6 flex-1 bg-gradient-to-b from-background to-muted/20">
              <SeatMap
                seatLayout={trip.seatLayout}
                seats={seats}
                preventGenderMixing={trip.seatLayout.preventGenderMixing}
              />
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  )
}
