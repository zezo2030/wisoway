// User Detail Page: Tabbed user profile view with related data
// T022: Implements user profile, stats, and tabs for trips, bookings, payments, ratings

import { useState } from "react"
import { useParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useLanguage } from "@/providers/language-provider"
import {
  getUserById,
  getUserStats,
  getTrips,
  getBookings,
  getDriverVehicle,
  changeUserRole,
  confirmUser,
  approveDriver,
  deleteUser,
  banUser,
  unbanUser,
  getUserDevices,
} from "@/api/admin"
import { StatusBadge } from "@/components/status-badge"
import { Badge } from "@/components/ui/badge"
import { ImagePreview } from "@/components/image-preview"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { QUERY_KEYS } from "@/lib/constants"
import { cn, formatDate, formatLocationName, formatPhone, getUserRoleLabel, getTripLocationName } from "@/lib/utils"
import { formatSeatDisplay } from "@/lib/seat-format"
import { UserRole } from "@/types/enums"
import type { Booking, TripSummary, UserSummary } from "@/types/models"
import {
  ArrowLeft,
  MoreHorizontal,
  User,
  UserCog,
  Ban,
  CheckCircle,
  Shield,
  Star,
  MapPin,
  CreditCard,
  Car,
  Mail,
  Phone,
  Calendar,
  Activity,
  Award,
  UserCheck,
  CarFront,
  Trash2,
  FileText,
  Smartphone,
} from "lucide-react"
import { toast } from "sonner"

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { t } = useLanguage()
  const [activeTab, setActiveTab] = useState("trips")

  // Ban reason dialog state
  const [banDialog, setBanDialog] = useState<{
    open: boolean
    userId: string
    banReason: string
  }>({ open: false, userId: "", banReason: "" })

  // Confirmation dialog state
  const [confirmDialog, setConfirmDialog] = useState<{
    open: boolean
    title: string
    description: string
    onConfirm: () => void
    variant: "default" | "destructive"
  }>({
    open: false,
    title: "",
    description: "",
    onConfirm: () => { },
    variant: "default",
  })

  // Fetch user data
  const { data: user, isLoading: isLoadingUser } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USER, id],
    queryFn: () => getUserById(id!),
    enabled: !!id,
  })

  // Fetch user stats
  const { data: stats } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USER_STATS, id],
    queryFn: () => getUserStats(id!),
    enabled: !!id,
  })

  // Fetch user's trips (if driver)
  const { data: trips } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.TRIPS, { driverId: id }],
    queryFn: () => getTrips({ driverId: id!, page: 1, limit: 10 }),
    enabled: !!id && activeTab === "trips" && user?.role === UserRole.DRIVER,
  })

  const { data: vehicle } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.VEHICLES, { driverId: id }],
    queryFn: () => getDriverVehicle(id!),
    enabled: !!id && user?.role === UserRole.DRIVER,
  })

  const bookingsParams = user?.role === UserRole.DRIVER
    ? { driverId: id!, page: 1, limit: 20 }
    : { userId: id!, page: 1, limit: 20 }

  const { data: bookings, isLoading: isLoadingBookings } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.BOOKINGS, bookingsParams],
    queryFn: () => getBookings(bookingsParams),
    enabled: !!id && !!user && activeTab === "bookings",
  })

  // Change role mutation
  const changeRoleMutation = useMutation({
    mutationFn: ({ userId, role }: { userId: string; role: UserRole }) =>
      changeUserRole(userId, role),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success(t("userRoleUpdated"))
    },
    onError: () => {
      toast.error(t("failedToUpdateRole"))
    },
  })

  // Phase 8 ban mutation — POST /admin/users/:id/ban with optional reason
  const banMutation = useMutation({
    mutationFn: ({ userId, banReason }: { userId: string; banReason?: string }) =>
      banUser(userId, banReason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER_DEVICES, id] })
      toast.success(t("userBanned"))
    },
    onError: () => {
      toast.error(t("failedToBanUser"))
    },
  })

  // Phase 8 unban mutation — POST /admin/users/:id/unban
  const unbanMutation = useMutation({
    mutationFn: (userId: string) => unbanUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER_DEVICES, id] })
      toast.success(t("userUnbanned"))
    },
    onError: () => {
      toast.error(t("failedToUnbanUser"))
    },
  })

  // Fetch user devices (lazy — only when devices tab is active)
  const { data: devices, isLoading: isLoadingDevices } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USER_DEVICES, id],
    queryFn: () => getUserDevices(id!),
    enabled: !!id && activeTab === "devices",
  })

  const confirmUserMutation = useMutation({
    mutationFn: (userId: string) => confirmUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success(t("userConfirmed"))
    },
    onError: () => {
      toast.error(t("failedToConfirmUser"))
    },
  })

  const approveDriverMutation = useMutation({
    mutationFn: ({ userId, approved }: { userId: string; approved: boolean }) =>
      approveDriver(userId, approved),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success(variables.approved ? t("driverApproved") : t("driverRejected"))
    },
    onError: () => {
      toast.error(t("failedToUpdateDriverApproval"))
    },
  })

  const deleteUserMutation = useMutation({
    mutationFn: (userId: string) => deleteUser(userId),
    onSuccess: () => {
      toast.success(t("userDeleted"))
      navigate("/users")
    },
    onError: () => {
      toast.error(t("failedToDeleteUser"))
    },
  })

  const handleRoleChange = (newRole: UserRole) => {
    if (!user) return

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error(t("cannotChangeRoleMissingId"))
      return
    }

    setConfirmDialog({
      open: true,
      title: t("roleConfirmTitle"),
      description: `${t("roleConfirmDesc")} ${getUserRoleLabel(newRole)}?`,
      variant: "default",
      onConfirm: () => {
        changeRoleMutation.mutate({ userId, role: newRole })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleBanClick = () => {
    if (!user) return
    if (user.role === UserRole.ADMIN) {
      toast.error(t("cannotBanAdmin"))
      return
    }
    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error(t("cannotBanMissingId"))
      return
    }
    setBanDialog({ open: true, userId, banReason: "" })
  }

  const handleUnbanClick = () => {
    if (!user) return
    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error(t("cannotUnbanMissingId"))
      return
    }
    setConfirmDialog({
      open: true,
      title: t("unbanConfirmTitle"),
      description: t("unbanConfirmDescDetail"),
      variant: "default",
      onConfirm: () => {
        unbanMutation.mutate(userId)
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleConfirmUser = () => {
    if (!user) return

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error(t("cannotConfirmMissingId"))
      return
    }

    setConfirmDialog({
      open: true,
      title: t("confirmUserTitle"),
      description: t("confirmUserDesc"),
      variant: "default",
      onConfirm: () => {
        confirmUserMutation.mutate(userId)
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleDeleteUser = () => {
    if (!user) return

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error(t("cannotDeleteMissingId"))
      return
    }

    setConfirmDialog({
      open: true,
      title: t("deleteConfirmTitle"),
      description:
        t("deleteConfirmDesc"),
      variant: "destructive",
      onConfirm: () => {
        deleteUserMutation.mutate(userId)
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleApproveDriver = () => {
    if (!user) return

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error(t("cannotApprovalMissingId"))
      return
    }

    const approving = !user.isDriverApproved
    setConfirmDialog({
      open: true,
      title: approving ? t("approveDriverTitle") : t("rejectDriverTitle"),
      description: approving
        ? t("approveDriverDesc")
        : t("rejectDriverDesc"),
      variant: approving ? "default" : "destructive",
      onConfirm: () => {
        approveDriverMutation.mutate({ userId, approved: approving })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const getInitials = (name: string) => {
    return name
      .split(" ")
      .map((n) => n[0])
      .join("")
      .toUpperCase()
      .slice(0, 2)
  }

  const getUserLocationText = (): string => {
    const userRecord = user as unknown as Record<string, unknown>
    const directFields = ["address", "city", "currentCity", "currentLocation"]

    for (const field of directFields) {
      const value = formatLocationName(userRecord[field], "")
      if (value) {
        return value
      }
    }

    const nestedLocation = userRecord.location
    if (typeof nestedLocation === "object" && nestedLocation !== null) {
      const locationRecord = nestedLocation as Record<string, unknown>
      const locationName = formatLocationName(locationRecord.name, "")
      if (locationName) {
        return locationName
      }

      const locationAddress = formatLocationName(locationRecord.address, "")
      if (locationAddress) {
        return locationAddress
      }
    }

    return t("locationNotProvided")
  }

  const isPopulatedUser = (value: Booking["userId"]): value is UserSummary =>
    typeof value === "object" && value !== null && "name" in value

  const isPopulatedTrip = (value: Booking["tripId"]): value is TripSummary =>
    typeof value === "object" && value !== null

  const getBookingTripText = (booking: Booking): string => {
    if (!isPopulatedTrip(booking.tripId)) return booking.tripId
    const tripRecord = booking.tripId as unknown as Record<string, unknown>
    const from = getTripLocationName(tripRecord, "from", "-")
    const to = getTripLocationName(tripRecord, "to", "-")
    return `${from || "-"} → ${to || "-"}`
  }

  const getBookingSeatText = (booking: Booking): string => {
    const layout = isPopulatedTrip(booking.tripId) ? booking.tripId.seatLayout : undefined
    if (booking.seats && booking.seats.length > 0) {
      return booking.seats
        .map((seat) => formatSeatDisplay(seat.seatNumber, layout))
        .join(", ")
    }
    return formatSeatDisplay(booking.seatNumber ?? "", layout)
  }

  if (isLoadingUser) {
    return (
      <div className="space-y-6 animate-in fade-in duration-500">
        <div className="flex items-center gap-4">
          <div className="h-10 w-24 animate-pulse rounded-full bg-muted/60" />
        </div>
        <div className="h-48 animate-pulse rounded-3xl bg-muted/60" />
      </div>
    )
  }

  if (!user) {
    return (
      <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
        <Button variant="ghost" onClick={() => navigate(-1)} className="rounded-full shadow-sm bg-background border border-border/50">
          <ArrowLeft className="mr-2 h-4 w-4" />
          {t("backToUsers")}
        </Button>
        <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl">
          <CardContent className="flex flex-col items-center justify-center h-64 text-muted-foreground">
            <User className="h-12 w-12 mb-4 text-muted-foreground/30" />
            <h3 className="text-xl font-bold text-foreground">{t("userNotFound")}</h3>
            <p className="mt-2 text-center text-sm">{t("userNotFoundDesc")}</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  const statCardsData = [
    {
      title: t("totalTripsLabel"),
      value: stats?.totalTrips || 0,
      icon: Car,
      color: "from-blue-500/20 to-indigo-500/20",
      textColor: "text-blue-500 font-black",
      iconColor: "text-blue-500"
    },
    {
      title: t("totalBookingsLabel"),
      value: stats?.totalBookings || 0,
      icon: MapPin,
      color: "from-violet-500/20 to-purple-500/20",
      textColor: "text-violet-500 font-black",
      iconColor: "text-violet-500"
    },
    {
      title: t("avgRating"),
      value: (stats?.averageRating != null ? Number(stats.averageRating).toFixed(1) : "0.0"),
      icon: Award,
      color: "from-amber-500/20 to-orange-500/20",
      textColor: "text-amber-500 font-black",
      iconColor: "text-amber-500",
      isRating: true
    },
    {
      title: t("paymentsLabel"),
      value: "$" + (stats?.totalPayments || 0),
      icon: CreditCard,
      color: "from-emerald-500/20 to-teal-500/20",
      textColor: "text-emerald-500 font-black",
      iconColor: "text-emerald-500"
    }
  ]

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between sticky top-14 z-20 bg-background/80 backdrop-blur-xl py-4 -mx-4 px-4 sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8 border-b border-border/40 shadow-sm">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" onClick={() => navigate(-1)} className="rounded-full bg-muted/60 hover:bg-muted border border-border/50 transition-colors">
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-foreground/90 flex items-center">
              {t("userProfile")}
              {user.isActive ? (
                <CheckCircle className="ml-3 h-5 w-5 text-emerald-500" />
              ) : (
                <Ban className="ml-3 h-5 w-5 text-rose-500" />
              )}
            </h1>
          </div>
        </div>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" className="rounded-full shadow-sm hover:shadow-md transition-all border-primary/20 hover:border-primary/50">
              <MoreHorizontal className="mr-2 h-4 w-4 text-primary" />
              <span className="font-semibold text-primary">{t("manageUser")}</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48 shadow-lg rounded-xl border-border/50 backdrop-blur-md bg-background/95">
            <div className="text-xs font-semibold px-2 py-1.5 text-muted-foreground uppercase tracking-wider">{t("roles")}</div>
            <DropdownMenuItem
              onClick={() => handleRoleChange(UserRole.PASSENGER)}
              disabled={user.role === UserRole.PASSENGER || changeRoleMutation.isPending}
              className="font-medium cursor-pointer"
            >
              <User className="mr-2 h-4 w-4" /> {t("makePassenger")}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleRoleChange(UserRole.DRIVER)}
              disabled={user.role === UserRole.DRIVER || changeRoleMutation.isPending}
              className="font-medium cursor-pointer"
            >
              <UserCog className="mr-2 h-4 w-4" /> {t("makeDriver")}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleRoleChange(UserRole.ADMIN)}
              disabled={user.role === UserRole.ADMIN || changeRoleMutation.isPending}
              className="font-medium cursor-pointer"
            >
              <Shield className="mr-2 h-4 w-4" /> {t("makeAdmin")}
            </DropdownMenuItem>
            <div className="h-px bg-border my-1" />
            <DropdownMenuItem
              onClick={user.isActive ? handleBanClick : handleUnbanClick}
              disabled={banMutation.isPending || unbanMutation.isPending || (user.role === UserRole.ADMIN && user.isActive)}
              className={cn("font-medium cursor-pointer", user.isActive ? "text-rose-600 focus:text-rose-600 focus:bg-rose-50 dark:focus:bg-rose-950/30" : "text-emerald-600 focus:text-emerald-600 focus:bg-emerald-50 dark:focus:bg-emerald-950/30")}
            >
              {user.isActive ? (
                <><Ban className="mr-2 h-4 w-4" /> {t("banUser")}</>
              ) : (
                <><CheckCircle className="mr-2 h-4 w-4" /> {t("unbanUser")}</>
              )}
            </DropdownMenuItem>
            {!user.isPhoneVerified && (
              <DropdownMenuItem
                onClick={handleConfirmUser}
                disabled={confirmUserMutation.isPending}
                className="font-medium cursor-pointer text-blue-600 focus:text-blue-600 focus:bg-blue-50 dark:focus:bg-blue-950/30"
              >
                <UserCheck className="mr-2 h-4 w-4" /> {t("confirmUser")}
              </DropdownMenuItem>
            )}
            {user.role === UserRole.DRIVER && (
              <DropdownMenuItem
                onClick={handleApproveDriver}
                disabled={approveDriverMutation.isPending}
                className={cn(
                  "font-medium cursor-pointer",
                  user.isDriverApproved
                    ? "text-orange-600 focus:text-orange-600 focus:bg-orange-50 dark:focus:bg-orange-950/30"
                    : "text-emerald-600 focus:text-emerald-600 focus:bg-emerald-50 dark:focus:bg-emerald-950/30"
                )}
              >
                <CarFront className="mr-2 h-4 w-4" />
                {user.isDriverApproved ? t("rejectDriver") : t("approveDriver")}
              </DropdownMenuItem>
            )}
            <DropdownMenuItem
              onClick={handleDeleteUser}
              disabled={deleteUserMutation.isPending || user.role === UserRole.ADMIN}
              className="font-medium cursor-pointer text-rose-600 focus:text-rose-600 focus:bg-rose-50 dark:focus:bg-rose-950/30"
            >
              <Trash2 className="mr-2 h-4 w-4" /> {t("deleteUser")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Main Profile Info Section */}
      <div className="grid gap-6 grid-cols-1 lg:grid-cols-3">
        {/* Left Column - Avatar & Core Info */}
        <Card className="lg:col-span-1 border-none shadow-xl bg-gradient-to-br from-card to-muted/20 relative overflow-hidden transition-all duration-300">
          <div className="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full blur-3xl -mr-10 -mt-10 pointer-events-none" />
          <CardContent className="pt-8 pb-6 flex flex-col items-center justify-center text-center">
            <div className="relative mb-6 group">
              <div className="absolute inset-0 bg-primary rounded-full blur-lg opacity-20 group-hover:opacity-30 transition-opacity duration-300" />
              <Avatar className="h-32 w-32 shadow-lg border-4 border-background relative">
                <AvatarImage src={user.photoUrl} alt={user.name} />
                <AvatarFallback className="text-4xl font-extrabold bg-gradient-to-br from-primary/80 to-primary text-primary-foreground">{getInitials(user.name)}</AvatarFallback>
              </Avatar>
              <div className="absolute bottom-1 right-1 p-1.5 bg-background rounded-full shadow-md border border-border">
                <StatusBadge status={user.role} type="user" className="text-[10px] px-2 py-0.5 shadow-sm" />
              </div>
            </div>

            <h2 className="text-3xl font-bold tracking-tight mb-2 text-foreground/90">{user.name}</h2>

            <div className="flex items-center gap-1.5 mb-6 text-muted-foreground/80 font-medium">
              <Shield className="w-4 h-4" />
              <span>{user.isEmailVerified || user.isPhoneVerified ? t("verifiedAccount") : t("accountNotVerified")}</span> • <span className="capitalize">{user.gender || t("notSpecified")}</span>
            </div>

            <div className="flex flex-wrap gap-2 justify-center mb-6">
              <StatusBadge status={user.isActive ? "active" : "banned"} type="user" />
              {user.isPhoneVerified && (
                <span className="inline-flex items-center rounded-full bg-emerald-100/80 px-3 py-1 text-xs font-bold text-emerald-700 shadow-sm border border-emerald-200">
                  <Phone className="w-3 h-3 mr-1" /> Phone
                </span>
              )}
              {user.isEmailVerified && (
                <span className="inline-flex items-center rounded-full bg-emerald-100/80 px-3 py-1 text-xs font-bold text-emerald-700 shadow-sm border border-emerald-200">
                  <Mail className="w-3 h-3 mr-1" /> Email
                </span>
              )}
              {user.role === UserRole.DRIVER && (
                <span
                  className={cn(
                    "inline-flex items-center rounded-full px-3 py-1 text-xs font-bold shadow-sm border",
                    user.isDriverApproved
                      ? "bg-emerald-100/80 text-emerald-700 border-emerald-200"
                      : "bg-orange-100/80 text-orange-700 border-orange-200"
                  )}
                >
                  <CarFront className="w-3 h-3 mr-1" />
                  {user.isDriverApproved ? t("driverApprovedBadge") : t("driverPending")}
                </span>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4 w-full p-4 bg-background/50 rounded-2xl border border-border/40 shadow-inner">
              <div className="flex flex-col items-center p-3 rounded-xl bg-card shadow-sm border border-border/50">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">{t("reviews")}</span>
                <div className="flex items-center gap-1 text-lg font-black text-amber-500">
                  <Star className="h-4 w-4 fill-amber-500" /> {Number(user.rating ?? 0).toFixed(1)}
                </div>
              </div>
              <div className="flex flex-col items-center p-3 rounded-xl bg-card shadow-sm border border-border/50">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">{t("joined")}</span>
                <span className="text-sm font-semibold text-foreground/80 mt-1">{new Date(user.createdAt).toLocaleDateString(undefined, { month: 'short', year: 'numeric' })}</span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Right Column - Details & Stats */}
        <div className="lg:col-span-2 space-y-6">
          <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl">
            <CardHeader className="pb-4">
              <CardTitle className="text-lg font-bold flex items-center">
                <User className="h-5 w-5 mr-2 text-primary" /> {t("contactDetails")}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid gap-5 sm:grid-cols-2">
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Mail className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Mail className="w-3.5 h-3.5" /> {t("emailAddress")}</p>
                  <p className="font-semibold text-foreground truncate">{user.email || t("notProvided")}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Phone className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Phone className="w-3.5 h-3.5" /> {t("phoneNumber")}</p>
                  <p className="font-semibold text-foreground" dir="ltr">{user.phoneNumber ? formatPhone(user.phoneNumber) : t("notProvided")}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Shield className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Shield className="w-3.5 h-3.5" /> {t("providerAuth")}</p>
                  <p className="font-semibold text-foreground capitalize">{user.provider}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Calendar className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Calendar className="w-3.5 h-3.5" /> {t("exactRegistration")}</p>
                  <p className="font-medium text-sm text-foreground">{formatDate(user.createdAt)}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors sm:col-span-2">
                  <MapPin className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><MapPin className="w-3.5 h-3.5" /> {t("locationLabel")}</p>
                  <p className="font-semibold text-foreground">{getUserLocationText()}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {user.role === UserRole.DRIVER && (
            <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl">
              <CardHeader className="pb-4">
                <CardTitle className="text-lg font-bold flex items-center">
                <CarFront className="h-5 w-5 mr-2 text-primary" /> {t("vehicleInformation")}
                </CardTitle>
              </CardHeader>
              <CardContent>
                {vehicle ? (
                  <div className="grid gap-5 sm:grid-cols-2">
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("type")}</p>
                      <p className="font-semibold text-foreground capitalize">{vehicle.vehicleType}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("vehicleModel")}</p>
                      <p className="font-semibold text-foreground">{vehicle.model}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("plateNumber")}</p>
                      <p className="font-semibold text-foreground">{vehicle.plateNumber}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("seats")}</p>
                      <p className="font-semibold text-foreground">{vehicle.seats}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40 sm:col-span-2">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("vehicleVerification")}</p>
                      <p className={cn("font-semibold", vehicle.isVerified ? "text-emerald-600" : "text-orange-600")}>
                        {vehicle.isVerified ? t("verified") : t("vehiclePendingRejected")}
                      </p>
                    </div>
                    {/* Driver License Image */}
                    <div className="space-y-2 p-4 rounded-xl bg-muted/20 border border-border/40 sm:col-span-2">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("driverLicense")}</p>
                      {vehicle.licenseImageUrl ? (
                        vehicle.licenseImageUrl.toLowerCase().endsWith(".pdf") ? (
                          <a
                            href={vehicle.licenseImageUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-blue-600 bg-blue-50 dark:bg-blue-950/30 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/50 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
                          >
                            <FileText className="h-4 w-4" />
                            {t("pdfDocument")}
                          </a>
                        ) : (
                          <ImagePreview
                            imageUrl={vehicle.licenseImageUrl}
                            alt={t("driverLicense")}
                            thumbnailClassName="h-24 w-auto max-w-[200px] rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:opacity-90 transition-opacity"
                          />
                        )
                      ) : (
                        <span className="text-sm text-muted-foreground">{t("noImageUploaded")}</span>
                      )}
                    </div>
                    {/* Vehicle Registration Image */}
                    <div className="space-y-2 p-4 rounded-xl bg-muted/20 border border-border/40 sm:col-span-2">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">{t("vehicleRegistration")}</p>
                      {vehicle.vehicleLicenseImageUrl ? (
                        vehicle.vehicleLicenseImageUrl.toLowerCase().endsWith(".pdf") ? (
                          <a
                            href={vehicle.vehicleLicenseImageUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-blue-600 bg-blue-50 dark:bg-blue-950/30 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/50 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
                          >
                            <FileText className="h-4 w-4" />
                            {t("pdfDocument")}
                          </a>
                        ) : (
                          <ImagePreview
                            imageUrl={vehicle.vehicleLicenseImageUrl}
                            alt={t("vehicleRegistration")}
                            thumbnailClassName="h-24 w-auto max-w-[200px] rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:opacity-90 transition-opacity"
                          />
                        )
                      ) : (
                        <span className="text-sm text-muted-foreground">{t("noImageUploaded")}</span>
                      )}
                    </div>
                  </div>
                ) : (
                  <div className="p-6 rounded-xl bg-muted/20 border border-border/40 text-sm text-muted-foreground">
                    {t("noVehicleData")}
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {/* User Metrics Summary */}
          {stats ? (
            <div className="grid grid-cols-2 gap-4">
              {statCardsData.map((stat) => {
                const Icon = stat.icon
                return (
                  <Card key={stat.title} className="border-none shadow-md overflow-hidden relative group">
                    <div className={cn("absolute inset-0 bg-gradient-to-br opacity-50 transition-opacity duration-300 group-hover:opacity-70", stat.color)} />
                    <CardContent className="p-5 flex items-center justify-between relative z-10">
                      <div>
                        <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1 opacity-80">{stat.title}</p>
                        <p className={cn("text-2xl", stat.textColor)}>
                          {stat.value} {stat.isRating && <span className="text-sm font-semibold opacity-70 ml-1">/ 5.0</span>}
                        </p>
                      </div>
                      <div className={cn("p-3 rounded-2xl bg-background/80 shadow-sm backdrop-blur-sm", stat.iconColor)}>
                        <Icon className="w-6 h-6" />
                      </div>
                    </CardContent>
                  </Card>
                )
              })}
            </div>
          ) : (
            <div className="h-32 rounded-xl bg-muted/50 border border-border/40 animate-pulse flex items-center justify-center text-muted-foreground font-medium">
              {t("loadingMetrics")}
            </div>
          )}
        </div>
      </div>

      {/* Tabs Section */}
      <div className="mt-8">
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="bg-muted/40 p-1.5 rounded-2xl border border-border/40 w-full flex overflow-x-auto overflow-y-hidden justify-start sm:w-auto h-auto min-w-min">
            <TabsTrigger value="trips" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <Car className="mr-2 h-4 w-4" /> {t("tripsLog")}
            </TabsTrigger>
            <TabsTrigger value="bookings" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <MapPin className="mr-2 h-4 w-4" /> {t("bookingsTitle")}
            </TabsTrigger>
            <TabsTrigger value="payments" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <CreditCard className="mr-2 h-4 w-4" /> {t("paymentsLabel")}
            </TabsTrigger>
            <TabsTrigger value="ratings" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <Star className="mr-2 h-4 w-4" /> {t("ratingsTab")}
            </TabsTrigger>
            <TabsTrigger value="devices" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <Smartphone className="mr-2 h-4 w-4" /> {t("userDevicesTab")}
            </TabsTrigger>
          </TabsList>

          <Card className="mt-6 border-border/50 shadow-md bg-card/60 backdrop-blur-xl mb-10 overflow-hidden">
            <TabsContent value="trips" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              {user.role === UserRole.DRIVER ? (
                trips && trips.data.length > 0 ? (
                  <div>
                    <CardHeader className="border-b border-border/30 bg-muted/10 pb-4 pt-5 px-6">
                      <CardTitle className="text-lg font-bold flex items-center">
                        <Activity className="w-5 h-5 mr-3 text-primary" /> {t("activePastDriverTrips")}
                      </CardTitle>
                      <CardDescription className="text-sm font-medium">{t("recentDrives")}</CardDescription>
                    </CardHeader>
                    <div className="p-0">
                      <div className="divide-y divide-border/50">
                        {trips.data.map((trip, index) => (
                          <div key={trip._id || trip.id || `${trip.departureTime}-${index}`} className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:bg-muted/30 transition-colors">
                            <div className="flex items-start gap-4">
                              <div className="bg-primary/10 p-3 rounded-xl border border-primary/20 shadow-inner mt-1 sm:mt-0">
                                <Car className="w-5 h-5 text-primary" />
                              </div>
                              <div>
                                <p className="font-bold text-base text-foreground mb-1 flex items-center">
                                  {getTripLocationName(trip as unknown as Record<string, unknown>, "from")} <ArrowLeft className="w-4 h-4 mx-2 text-muted-foreground rotate-180" /> {getTripLocationName(trip as unknown as Record<string, unknown>, "to")}
                                </p>
                                <p className="text-sm font-medium text-muted-foreground flex items-center">
                                  <Calendar className="w-3.5 h-3.5 mr-1.5" /> {formatDate(trip.departureTime)}
                                  <span className="mx-2 text-border">•</span>
                                  <span className="font-bold text-primary">${trip.price}</span>
                                </p>
                              </div>
                            </div>
                            <div className="pl-14 sm:pl-0">
                              <StatusBadge status={trip.status} type="trip" className="shadow-sm font-semibold" />
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="p-16 flex flex-col items-center justify-center text-center">
                    <div className="bg-muted p-4 rounded-full mb-4">
                      <Car className="h-8 w-8 text-muted-foreground/50" />
                    </div>
                    <h3 className="text-lg font-bold">{t("noTripsOnRecord")}</h3>
                    <p className="text-muted-foreground mt-1 text-sm max-w-[250px]">{t("driverNoTrips")}</p>
                  </div>
                )
              ) : (
                <div className="p-16 flex flex-col items-center justify-center text-center">
                  <div className="bg-muted w-16 h-16 rounded-full flex items-center justify-center mb-4">
                    <User className="h-8 w-8 text-muted-foreground/50" />
                  </div>
                  <h3 className="text-lg font-bold">{t("cannotShowTrips")}</h3>
                  <p className="text-muted-foreground mt-1 text-sm max-w-[250px]">{t("passengerNoTrips")}</p>
                </div>
              )}
            </TabsContent>

            <TabsContent value="bookings" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              {isLoadingBookings ? (
                <div className="p-16 flex flex-col items-center justify-center text-center">
                  <MapPin className="h-12 w-12 mb-4 text-muted-foreground/30 animate-pulse" />
                  <p className="text-sm text-muted-foreground font-medium">{t("loading")}</p>
                </div>
              ) : bookings && bookings.data.length > 0 ? (
                <div>
                  <CardHeader className="border-b border-border/30 bg-muted/10 pb-4 pt-5 px-6">
                    <CardTitle className="text-lg font-bold flex items-center">
                      <MapPin className="w-5 h-5 mr-3 text-primary" /> {t("bookingsTitle")}
                    </CardTitle>
                    <CardDescription className="text-sm font-medium">
                      {t("totalBookingsLabel")}: {bookings.meta.total}
                    </CardDescription>
                  </CardHeader>
                  <div className="divide-y divide-border/50">
                    {bookings.data.map((booking) => (
                      <div
                        key={booking._id}
                        className="p-5 flex flex-col gap-4 hover:bg-muted/30 transition-colors lg:flex-row lg:items-center lg:justify-between"
                      >
                        <div className="space-y-2 min-w-0">
                          <div className="flex flex-wrap items-center gap-2">
                            <h4 className="font-bold text-base text-foreground">
                              {getBookingTripText(booking)}
                            </h4>
                            <StatusBadge
                              status={
                                booking.status === "pending" ? "pending_booking"
                                : booking.status === "confirmed" ? "confirmed"
                                : booking.status === "cancelled" ? "cancelled_booking"
                                : booking.status === "rejected" ? "rejected"
                                : booking.status === "no_show" ? "no_show"
                                : "completed_booking"
                              }
                              type="booking"
                              className="shadow-sm"
                            />
                          </div>
                          <div className="flex flex-wrap gap-x-4 gap-y-1 text-sm text-muted-foreground font-medium">
                            {isPopulatedTrip(booking.tripId) && (
                              <span className="flex items-center">
                                <Calendar className="w-3.5 h-3.5 mr-1.5" />
                                {formatDate(booking.tripId.departureTime)}
                              </span>
                            )}
                            {user.role === UserRole.DRIVER && isPopulatedUser(booking.userId) && (
                              <span className="flex items-center">
                                <User className="w-3.5 h-3.5 mr-1.5" />
                                {booking.userId.name}
                              </span>
                            )}
                            <span className="flex items-center">
                              <CreditCard className="w-3.5 h-3.5 mr-1.5" />
                              {booking.totalAmount ?? 0}
                            </span>
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center gap-2">
                          <Badge variant="secondary" className="font-mono">
                            #{getBookingSeatText(booking)}
                          </Badge>
                          {booking.seatCount && booking.seatCount > 1 && (
                            <Badge variant="outline">
                              {booking.seatCount} {t("seatsColumn")}
                            </Badge>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="p-16 flex flex-col items-center justify-center text-center">
                  <div className="bg-muted w-16 h-16 rounded-full flex items-center justify-center mb-4">
                    <MapPin className="h-8 w-8 text-muted-foreground/50" />
                  </div>
                  <h3 className="text-lg font-bold">{t("noBookingsFound")}</h3>
                  <p className="text-muted-foreground mt-1 text-sm max-w-[280px]">
                    {t("noBookingsFound")}
                  </p>
                </div>
              )}
            </TabsContent>

            <TabsContent value="payments" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              <div className="p-16 flex flex-col items-center justify-center text-center">
                <CreditCard className="h-12 w-12 mb-4 text-emerald-500/30" />
                <h3 className="text-xl font-bold">{t("totalPaymentsLabel")}: ${stats?.totalPayments || 0}</h3>
                <p className="mt-2 text-sm text-muted-foreground font-medium">{t("paymentsComingSoon")}</p>
              </div>
            </TabsContent>

            <TabsContent value="ratings" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              <div className="p-16 flex flex-col items-center justify-center text-center">
                <Star className="h-12 w-12 mb-4 text-yellow-500/30" />
                <h3 className="text-xl font-bold">{t("totalRatingsLabel")}: {stats?.totalRatings || 0}</h3>
                <p className="mt-2 text-sm text-muted-foreground font-medium">{t("ratingsComingSoon")}</p>
              </div>
            </TabsContent>

            <TabsContent value="devices" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              {isLoadingDevices ? (
                <div className="p-16 flex flex-col items-center justify-center text-center">
                  <Smartphone className="h-12 w-12 mb-4 text-muted-foreground/30 animate-pulse" />
                  <p className="text-sm text-muted-foreground font-medium">{t("loadingDevices")}</p>
                </div>
              ) : devices && devices.length > 0 ? (
                <div>
                  <CardHeader className="border-b border-border/30 bg-muted/10 pb-4 pt-5 px-6">
                    <CardTitle className="text-lg font-bold flex items-center">
                        <Smartphone className="w-5 h-5 mr-3 text-primary" /> {t("registeredDevices")}
                      </CardTitle>
                      <CardDescription className="text-sm font-medium">
                        {devices.filter((d) => d.status === "active").length} {t("activeDevices")} · {devices.filter((d) => d.status === "revoked").length} {t("revokedDevices")}
                    </CardDescription>
                  </CardHeader>
                  <div className="divide-y divide-border/50">
                    {devices.map((device) => (
                      <div key={device.id} className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-muted/30 transition-colors">
                        <div className="flex items-start gap-4">
                          <div className={cn(
                            "p-3 rounded-xl border shadow-inner mt-0.5",
                            device.status === "active"
                              ? "bg-emerald-500/10 border-emerald-500/20"
                              : "bg-muted border-border/40"
                          )}>
                            <Smartphone className={cn("w-5 h-5", device.status === "active" ? "text-emerald-600" : "text-muted-foreground/50")} />
                          </div>
                          <div>
                            <p className="font-bold text-base text-foreground">
                              {device.deviceName || device.deviceId}
                            </p>
                            <p className="text-sm text-muted-foreground capitalize">
                              {device.platform}
                              {device.lastSeenAt && (
                                <span className="ml-2">· {t("lastSeenLabel")} {formatDate(device.lastSeenAt)}</span>
                              )}
                            </p>
                            {device.revokeReason && (
                              <p className="text-xs text-rose-500 mt-0.5">{t("revokedLabel")} {device.revokeReason}</p>
                            )}
                          </div>
                        </div>
                        <Badge
                          variant={device.status === "active" ? "default" : "outline"}
                          className={cn(
                            "shadow-sm font-semibold self-start sm:self-center capitalize",
                            device.status === "active" ? "bg-emerald-600 hover:bg-emerald-700 text-white" : "text-muted-foreground",
                          )}
                        >
                          {device.status}
                        </Badge>
                      </div>
                    ))}
                  </div>
                </div>
              ) : (
                <div className="p-16 flex flex-col items-center justify-center text-center">
                  <Smartphone className="h-12 w-12 mb-4 text-muted-foreground/30" />
                  <h3 className="text-xl font-bold">{t("noDevicesRegistered")}</h3>
                  <p className="mt-2 text-sm text-muted-foreground font-medium">{t("noDevicesDesc")}</p>
                </div>
              )}
            </TabsContent>
          </Card>
        </Tabs>
      </div>

      {/* Confirmation Dialog */}
      <ConfirmDialog
        open={confirmDialog.open}
        onOpenChange={(open) =>
          setConfirmDialog((prev) => ({ ...prev, open }))
        }
        title={confirmDialog.title}
        description={confirmDialog.description}
        variant={confirmDialog.variant}
        onConfirm={confirmDialog.onConfirm}
      />

      {/* Ban Reason Dialog */}
      <Dialog open={banDialog.open} onOpenChange={(open) => setBanDialog((prev) => ({ ...prev, open }))}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-rose-600">
              <Ban className="h-5 w-5" /> {t("banUser")}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              {t("banDialogDesc")}
            </p>
            <div className="space-y-1.5">
              <Label htmlFor="ban-reason" className="text-sm font-semibold">
                {t("reasonLabel")} <span className="text-muted-foreground font-normal">({t("optional")})</span>
              </Label>
              <Textarea
                id="ban-reason"
                placeholder={t("banReasonPlaceholder")}
                className="resize-none min-h-[90px]"
                value={banDialog.banReason}
                onChange={(e) => setBanDialog((prev) => ({ ...prev, banReason: e.target.value }))}
              />
            </div>
          </div>
          <DialogFooter className="gap-2">
            <Button
              variant="outline"
              onClick={() => setBanDialog({ open: false, userId: "", banReason: "" })}
            >
              {t("cancel")}
            </Button>
            <Button
              variant="destructive"
              disabled={banMutation.isPending}
              onClick={() => {
                banMutation.mutate({
                  userId: banDialog.userId,
                  banReason: banDialog.banReason.trim() || undefined,
                })
                setBanDialog({ open: false, userId: "", banReason: "" })
              }}
            >
              {banMutation.isPending ? t("banning") : t("confirmBan")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
