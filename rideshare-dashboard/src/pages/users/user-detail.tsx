// User Detail Page: Tabbed user profile view with related data
// T022: Implements user profile, stats, and tabs for trips, bookings, payments, ratings

import { useState } from "react"
import { useParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  getUserById,
  getUserStats,
  getTrips,
  getDriverVehicle,
  changeUserRole,
  toggleUserBan,
  confirmUser,
  approveDriver,
  deleteUser,
} from "@/api/admin"
import { StatusBadge } from "@/components/status-badge"
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
import { QUERY_KEYS } from "@/lib/constants"
import { cn, formatDate, getUserRoleLabel, formatNumber } from "@/lib/utils"
import { UserRole } from "@/types/enums"
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
} from "lucide-react"
import { toast } from "sonner"

export default function UserDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState("trips")

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

  // Change role mutation
  const changeRoleMutation = useMutation({
    mutationFn: ({ userId, role }: { userId: string; role: UserRole }) =>
      changeUserRole(userId, role),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success("User role updated successfully")
    },
    onError: () => {
      toast.error("Failed to update user role")
    },
  })

  // Toggle ban mutation
  const toggleBanMutation = useMutation({
    mutationFn: ({ userId, isActive }: { userId: string; isActive: boolean }) =>
      toggleUserBan(userId, isActive),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success(variables.isActive ? "User unbanned successfully" : "User banned successfully")
    },
    onError: () => {
      toast.error("Failed to update user status")
    },
  })

  const confirmUserMutation = useMutation({
    mutationFn: (userId: string) => confirmUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success("User confirmed successfully")
    },
    onError: () => {
      toast.error("Failed to confirm user")
    },
  })

  const approveDriverMutation = useMutation({
    mutationFn: ({ userId, approved }: { userId: string; approved: boolean }) =>
      approveDriver(userId, approved),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USER, id] })
      toast.success(variables.approved ? "Driver approved successfully" : "Driver approval removed")
    },
    onError: () => {
      toast.error("Failed to update driver approval")
    },
  })

  const deleteUserMutation = useMutation({
    mutationFn: (userId: string) => deleteUser(userId),
    onSuccess: () => {
      toast.success("User deleted successfully")
      navigate("/users")
    },
    onError: () => {
      toast.error("Failed to delete user")
    },
  })

  const handleRoleChange = (newRole: UserRole) => {
    if (!user) return

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error("Cannot change role: missing user ID")
      return
    }

    setConfirmDialog({
      open: true,
      title: "Change User Role",
      description: `Are you sure you want to change this user's role to ${getUserRoleLabel(newRole)}?`,
      variant: "default",
      onConfirm: () => {
        changeRoleMutation.mutate({ userId, role: newRole })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleBanToggle = () => {
    if (!user) return
    // Prevent banning admin users
    if (user.role === UserRole.ADMIN && user.isActive) {
      toast.error("Cannot ban admin users")
      return
    }

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error("Cannot ban user: missing user ID")
      return
    }

    const isBanning = user.isActive
    setConfirmDialog({
      open: true,
      title: isBanning ? "Ban User" : "Unban User",
      description: isBanning
        ? "Are you sure you want to ban this user? They will no longer be able to access the platform."
        : "Are you sure you want to unban this user? They will regain access to the platform.",
      variant: isBanning ? "destructive" : "default",
      onConfirm: () => {
        toggleBanMutation.mutate({ userId, isActive: !user.isActive })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleConfirmUser = () => {
    if (!user) return

    const userId = (user as { id?: string }).id ?? user._id
    if (!userId) {
      toast.error("Cannot confirm user: missing user ID")
      return
    }

    setConfirmDialog({
      open: true,
      title: "Confirm User",
      description: "Are you sure you want to confirm this user account?",
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
      toast.error("Cannot delete user: missing user ID")
      return
    }

    setConfirmDialog({
      open: true,
      title: "Delete User",
      description:
        "Are you sure you want to permanently delete this user? This action cannot be undone.",
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
      toast.error("Cannot update driver approval: missing user ID")
      return
    }

    const approving = !user.isDriverApproved
    setConfirmDialog({
      open: true,
      title: approving ? "Approve Driver" : "Reject Driver",
      description: approving
        ? "Approve this driver to allow creating trips?"
        : "Reject this driver? They will no longer be allowed to create trips.",
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
          Back to Users
        </Button>
        <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl">
          <CardContent className="flex flex-col items-center justify-center h-64 text-muted-foreground">
            <User className="h-12 w-12 mb-4 text-muted-foreground/30" />
            <h3 className="text-xl font-bold text-foreground">User Not Found</h3>
            <p className="mt-2 text-center text-sm">The user you are looking for does not exist or has been removed.</p>
          </CardContent>
        </Card>
      </div>
    )
  }

  const statCardsData = [
    {
      title: "Total Trips",
      value: stats?.totalTrips || 0,
      icon: Car,
      color: "from-blue-500/20 to-indigo-500/20",
      textColor: "text-blue-500 font-black",
      iconColor: "text-blue-500"
    },
    {
      title: "Total Bookings",
      value: stats?.totalBookings || 0,
      icon: MapPin,
      color: "from-violet-500/20 to-purple-500/20",
      textColor: "text-violet-500 font-black",
      iconColor: "text-violet-500"
    },
    {
      title: "Avg. Rating",
      value: (stats?.averageRating != null ? Number(stats.averageRating).toFixed(1) : "0.0"),
      icon: Award,
      color: "from-amber-500/20 to-orange-500/20",
      textColor: "text-amber-500 font-black",
      iconColor: "text-amber-500",
      isRating: true
    },
    {
      title: "Payments",
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
              User Profile
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
              <span className="font-semibold text-primary">Manage User</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48 shadow-lg rounded-xl border-border/50 backdrop-blur-md bg-background/95">
            <div className="text-xs font-semibold px-2 py-1.5 text-muted-foreground uppercase tracking-wider">Roles</div>
            <DropdownMenuItem
              onClick={() => handleRoleChange(UserRole.PASSENGER)}
              disabled={user.role === UserRole.PASSENGER || changeRoleMutation.isPending}
              className="font-medium cursor-pointer"
            >
              <User className="mr-2 h-4 w-4" /> Make Passenger
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleRoleChange(UserRole.DRIVER)}
              disabled={user.role === UserRole.DRIVER || changeRoleMutation.isPending}
              className="font-medium cursor-pointer"
            >
              <UserCog className="mr-2 h-4 w-4" /> Make Driver
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleRoleChange(UserRole.ADMIN)}
              disabled={user.role === UserRole.ADMIN || changeRoleMutation.isPending}
              className="font-medium cursor-pointer"
            >
              <Shield className="mr-2 h-4 w-4" /> Make Admin
            </DropdownMenuItem>
            <div className="h-px bg-border my-1" />
            <DropdownMenuItem
              onClick={handleBanToggle}
              disabled={toggleBanMutation.isPending || (user.role === UserRole.ADMIN && user.isActive)}
              className={cn("font-medium cursor-pointer", user.isActive ? "text-rose-600 focus:text-rose-600 focus:bg-rose-50 dark:focus:bg-rose-950/30" : "text-emerald-600 focus:text-emerald-600 focus:bg-emerald-50 dark:focus:bg-emerald-950/30")}
            >
              {user.isActive ? (
                <><Ban className="mr-2 h-4 w-4" /> Ban User</>
              ) : (
                <><CheckCircle className="mr-2 h-4 w-4" /> Unban User</>
              )}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={handleConfirmUser}
              disabled={
                confirmUserMutation.isPending ||
                (user.isActive && user.isPhoneVerified && user.isEmailVerified)
              }
              className="font-medium cursor-pointer text-blue-600 focus:text-blue-600 focus:bg-blue-50 dark:focus:bg-blue-950/30"
            >
              <UserCheck className="mr-2 h-4 w-4" /> Confirm User
            </DropdownMenuItem>
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
                {user.isDriverApproved ? "Reject Driver" : "Approve Driver"}
              </DropdownMenuItem>
            )}
            <DropdownMenuItem
              onClick={handleDeleteUser}
              disabled={deleteUserMutation.isPending || user.role === UserRole.ADMIN}
              className="font-medium cursor-pointer text-rose-600 focus:text-rose-600 focus:bg-rose-50 dark:focus:bg-rose-950/30"
            >
              <Trash2 className="mr-2 h-4 w-4" /> Delete User
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
              <MapPin className="w-4 h-4" />
              <span>{user.isEmailVerified ? "Verified Account" : "Unverified"}</span> • <span className="capitalize">{user.gender || "Not specified"}</span>
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
                  {user.isDriverApproved ? "Driver Approved" : "Driver Pending"}
                </span>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4 w-full p-4 bg-background/50 rounded-2xl border border-border/40 shadow-inner">
              <div className="flex flex-col items-center p-3 rounded-xl bg-card shadow-sm border border-border/50">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">Reviews</span>
                <div className="flex items-center gap-1 text-lg font-black text-amber-500">
                  <Star className="h-4 w-4 fill-amber-500" /> {Number(user.rating ?? 0).toFixed(1)}
                </div>
              </div>
              <div className="flex flex-col items-center p-3 rounded-xl bg-card shadow-sm border border-border/50">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-1">Joined</span>
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
                <User className="h-5 w-5 mr-2 text-primary" /> Contact & Details
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid gap-5 sm:grid-cols-2">
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Mail className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Mail className="w-3.5 h-3.5" /> Email Address</p>
                  <p className="font-semibold text-foreground truncate">{user.email || "Not Provided"}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Phone className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Phone className="w-3.5 h-3.5" /> Phone Number</p>
                  <p className="font-semibold text-foreground">{user.phoneNumber || "Not Provided"}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Shield className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Shield className="w-3.5 h-3.5" /> Provider Auth</p>
                  <p className="font-semibold text-foreground capitalize">{user.provider}</p>
                </div>
                <div className="space-y-1 p-4 rounded-xl relative overflow-hidden bg-muted/20 border border-border/40 hover:bg-muted/40 transition-colors">
                  <Calendar className="w-16 h-16 absolute -right-4 -bottom-4 opacity-[0.03] text-foreground" />
                  <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground flex items-center gap-2"><Calendar className="w-3.5 h-3.5" /> Exact Registration</p>
                  <p className="font-medium text-sm text-foreground">{formatDate(user.createdAt)}</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {user.role === UserRole.DRIVER && (
            <Card className="border-border/50 shadow-md bg-card/60 backdrop-blur-xl">
              <CardHeader className="pb-4">
                <CardTitle className="text-lg font-bold flex items-center">
                  <CarFront className="h-5 w-5 mr-2 text-primary" /> Vehicle Information
                </CardTitle>
              </CardHeader>
              <CardContent>
                {vehicle ? (
                  <div className="grid gap-5 sm:grid-cols-2">
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Type</p>
                      <p className="font-semibold text-foreground capitalize">{vehicle.vehicleType}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Model</p>
                      <p className="font-semibold text-foreground">{vehicle.model}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Plate Number</p>
                      <p className="font-semibold text-foreground">{vehicle.plateNumber}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Seats</p>
                      <p className="font-semibold text-foreground">{vehicle.seats}</p>
                    </div>
                    <div className="space-y-1 p-4 rounded-xl bg-muted/20 border border-border/40 sm:col-span-2">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Verification</p>
                      <p className={cn("font-semibold", vehicle.isVerified ? "text-emerald-600" : "text-orange-600")}>
                        {vehicle.isVerified ? "Verified" : "Pending / Rejected"}
                      </p>
                    </div>
                    {/* Driver License Image */}
                    <div className="space-y-2 p-4 rounded-xl bg-muted/20 border border-border/40 sm:col-span-2">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Driver License</p>
                      {vehicle.licenseImageUrl ? (
                        vehicle.licenseImageUrl.toLowerCase().endsWith(".pdf") ? (
                          <a
                            href={vehicle.licenseImageUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-blue-600 bg-blue-50 dark:bg-blue-950/30 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/50 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
                          >
                            <FileText className="h-4 w-4" />
                            PDF Document
                          </a>
                        ) : (
                          <ImagePreview
                            imageUrl={vehicle.licenseImageUrl}
                            alt="Driver License"
                            thumbnailClassName="h-24 w-auto max-w-[200px] rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:opacity-90 transition-opacity"
                          />
                        )
                      ) : (
                        <span className="text-sm text-muted-foreground">No image uploaded</span>
                      )}
                    </div>
                    {/* Vehicle Registration Image */}
                    <div className="space-y-2 p-4 rounded-xl bg-muted/20 border border-border/40 sm:col-span-2">
                      <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">Vehicle Registration</p>
                      {vehicle.vehicleLicenseImageUrl ? (
                        vehicle.vehicleLicenseImageUrl.toLowerCase().endsWith(".pdf") ? (
                          <a
                            href={vehicle.vehicleLicenseImageUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-blue-600 bg-blue-50 dark:bg-blue-950/30 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/50 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
                          >
                            <FileText className="h-4 w-4" />
                            PDF Document
                          </a>
                        ) : (
                          <ImagePreview
                            imageUrl={vehicle.vehicleLicenseImageUrl}
                            alt="Vehicle Registration"
                            thumbnailClassName="h-24 w-auto max-w-[200px] rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:opacity-90 transition-opacity"
                          />
                        )
                      ) : (
                        <span className="text-sm text-muted-foreground">No image uploaded</span>
                      )}
                    </div>
                  </div>
                ) : (
                  <div className="p-6 rounded-xl bg-muted/20 border border-border/40 text-sm text-muted-foreground">
                    No vehicle data found for this driver.
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {/* User Metrics Summary */}
          {stats ? (
            <div className="grid grid-cols-2 gap-4">
              {statCardsData.map((stat, i) => {
                const Icon = stat.icon;
                return (
                  <Card key={i} className="border-none shadow-md overflow-hidden relative group">
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
              Loading user metrics...
            </div>
          )}
        </div>
      </div>

      {/* Tabs Section */}
      <div className="mt-8">
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="bg-muted/40 p-1.5 rounded-2xl border border-border/40 w-full flex overflow-x-auto overflow-y-hidden justify-start sm:w-auto h-auto min-w-min">
            <TabsTrigger value="trips" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <Car className="mr-2 h-4 w-4" /> Trips Log
            </TabsTrigger>
            <TabsTrigger value="bookings" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <MapPin className="mr-2 h-4 w-4" /> Bookings
            </TabsTrigger>
            <TabsTrigger value="payments" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <CreditCard className="mr-2 h-4 w-4" /> Payments
            </TabsTrigger>
            <TabsTrigger value="ratings" className="rounded-xl px-5 py-2.5 font-semibold text-sm transition-all data-[state=active]:bg-background data-[state=active]:shadow-sm data-[state=active]:text-primary flex-shrink-0">
              <Star className="mr-2 h-4 w-4" /> Ratings
            </TabsTrigger>
          </TabsList>

          <Card className="mt-6 border-border/50 shadow-md bg-card/60 backdrop-blur-xl mb-10 overflow-hidden">
            <TabsContent value="trips" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              {user.role === UserRole.DRIVER ? (
                trips && trips.data.length > 0 ? (
                  <div>
                    <CardHeader className="border-b border-border/30 bg-muted/10 pb-4 pt-5 px-6">
                      <CardTitle className="text-lg font-bold flex items-center">
                        <Activity className="w-5 h-5 mr-3 text-primary" /> Active & Past Driver Trips
                      </CardTitle>
                      <CardDescription className="text-sm font-medium">Recent drives organized by this user.</CardDescription>
                    </CardHeader>
                    <div className="p-0">
                      <div className="divide-y divide-border/50">
                        {trips.data.map((trip) => (
                          <div key={trip._id} className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:bg-muted/30 transition-colors">
                            <div className="flex items-start gap-4">
                              <div className="bg-primary/10 p-3 rounded-xl border border-primary/20 shadow-inner mt-1 sm:mt-0">
                                <Car className="w-5 h-5 text-primary" />
                              </div>
                              <div>
                                <p className="font-bold text-base text-foreground mb-1 flex items-center">
                                  {trip.from.name} <ArrowLeft className="w-4 h-4 mx-2 text-muted-foreground rotate-180" /> {trip.to.name}
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
                    <h3 className="text-lg font-bold">No trips on record</h3>
                    <p className="text-muted-foreground mt-1 text-sm max-w-[250px]">This driver hasn't completed or scheduled any trips yet.</p>
                  </div>
                )
              ) : (
                <div className="p-16 flex flex-col items-center justify-center text-center">
                  <div className="bg-muted w-16 h-16 rounded-full flex items-center justify-center mb-4">
                    <User className="h-8 w-8 text-muted-foreground/50" />
                  </div>
                  <h3 className="text-lg font-bold">Cannot show trips</h3>
                  <p className="text-muted-foreground mt-1 text-sm max-w-[250px]">This account is registered as a passenger, so they do not organize trips.</p>
                </div>
              )}
            </TabsContent>

            <TabsContent value="bookings" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              <div className="p-16 flex flex-col items-center justify-center text-center">
                <MapPin className="h-12 w-12 mb-4 text-muted-foreground/30" />
                <h3 className="text-xl font-bold">Total Bookings: {stats?.totalBookings || 0}</h3>
                <p className="mt-2 text-sm text-muted-foreground font-medium">Full booking details feature is in development.</p>
              </div>
            </TabsContent>

            <TabsContent value="payments" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              <div className="p-16 flex flex-col items-center justify-center text-center">
                <CreditCard className="h-12 w-12 mb-4 text-emerald-500/30" />
                <h3 className="text-xl font-bold">Total Payments: ${stats?.totalPayments || 0}</h3>
                <p className="mt-2 text-sm text-muted-foreground font-medium">Detailed transaction history coming soon.</p>
              </div>
            </TabsContent>

            <TabsContent value="ratings" className="m-0 focus-visible:outline-none focus-visible:ring-0">
              <div className="p-16 flex flex-col items-center justify-center text-center">
                <Star className="h-12 w-12 mb-4 text-yellow-500/30" />
                <h3 className="text-xl font-bold">Total Ratings given/received: {stats?.totalRatings || 0}</h3>
                <p className="mt-2 text-sm text-muted-foreground font-medium">Ratings breakdown module coming soon.</p>
              </div>
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
    </div>
  )
}
