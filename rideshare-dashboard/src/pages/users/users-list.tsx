// Users List Page: Paginated user list with search and filters
// T021: Implements users list with DataTable, search, filters, and navigation

import { useState, useCallback, useEffect } from "react"
import { useNavigate, useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getUsers, changeUserRole, toggleUserBan, confirmUser, deleteUser, approveDriver } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { useLanguage } from "@/providers/language-provider"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { QUERY_KEYS, DEFAULT_PAGE_SIZE } from "@/lib/constants"
import { cn, formatDate } from "@/lib/utils"
import { UserRole } from "@/types/enums"
import type { User } from "@/types/models"
import {
  Search,
  MoreHorizontal,
  UserCog,
  Ban,
  CheckCircle,
  Shield,
  User as UserIcon,
  Users as UsersIcon,
  Filter,
  UserCheck,
  Car,
  Trash2,
} from "lucide-react"
import { toast } from "sonner"

export default function UsersListPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const { t, language } = useLanguage()

  // URL state
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = parseInt(searchParams.get("limit") || String(DEFAULT_PAGE_SIZE), 10)
  const search = searchParams.get("search") || ""
  const roleFilter = searchParams.get("role") || ""
  const statusFilter = searchParams.get("status") || ""

  // Local state for search input (debounced)
  const [searchInput, setSearchInput] = useState(search)

  // Confirmation dialog state
  const [confirmDialog, setConfirmDialog] = useState<{
    open: boolean
    title: string
    description: string
    onConfirm: () => void
    variant: "default" | "destructive"
    pendingId?: string
  }>({
    open: false,
    title: "",
    description: "",
    onConfirm: () => { },
    variant: "default",
  })

  // Fetch users
  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USERS, { page, limit, search, role: roleFilter, status: statusFilter }],
    queryFn: () =>
      getUsers({
        page,
        limit,
        search: search || undefined,
        role: (roleFilter as UserRole) || undefined,
        isActive: statusFilter === "active" ? true : statusFilter === "banned" ? false : undefined,
      }),
  })

  // Mutations
  const changeRoleMutation = useMutation({
    mutationFn: ({ userId, role }: { userId: string; role: UserRole }) =>
      changeUserRole(userId, role),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      toast.success(t("userRoleUpdated"))
    },
    onError: () => {
      toast.error("Failed to update user role")
    },
  })

  const toggleBanMutation = useMutation({
    mutationFn: ({ userId, isActive }: { userId: string; isActive: boolean }) =>
      toggleUserBan(userId, isActive),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      toast.success(variables.isActive ? t("userUnbanned") : t("userBanned"))
    },
    onError: () => {
      toast.error("Failed to update user status")
    },
  })

  const confirmUserMutation = useMutation({
    mutationFn: (userId: string) => confirmUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      toast.success(t("userConfirmed"))
    },
    onError: () => {
      toast.error("Failed to confirm user")
    },
  })

  const deleteUserMutation = useMutation({
    mutationFn: (userId: string) => deleteUser(userId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      toast.success(t("userDeleted"))
    },
    onError: () => {
      toast.error("Failed to delete user")
    },
  })

  const approveDriverMutation = useMutation({
    mutationFn: ({ userId, approved }: { userId: string; approved: boolean }) =>
      approveDriver(userId, approved),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      toast.success(variables.approved ? t("driverApproved") : t("driverRejected"))
    },
    onError: () => {
      toast.error("Failed to update driver approval")
    },
  })

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchInput !== search) {
        updateSearchParams({ search: searchInput || null, page: "1" })
      }
    }, 300)
    return () => clearTimeout(timer)
  }, [searchInput, search])

  const updateSearchParams = useCallback(
    (updates: Record<string, string | null>) => {
      const newParams = new URLSearchParams(searchParams)
      Object.entries(updates).forEach(([key, value]) => {
        if (value === null) {
          newParams.delete(key)
        } else {
          newParams.set(key, value)
        }
      })
      setSearchParams(newParams)
    },
    [searchParams, setSearchParams]
  )

  const handlePageChange = (newPage: number) => {
    updateSearchParams({ page: String(newPage) })
  }

  const handleRoleChange = (userId: string, newRole: UserRole) => {
    const roleLabel = newRole === UserRole.PASSENGER ? t("role_passenger") : newRole === UserRole.DRIVER ? t("role_driver") : t("role_admin");
    setConfirmDialog({
      open: true,
      title: t("roleConfirmTitle"),
      description: `${t("roleConfirmDesc")} ${roleLabel}?`,
      variant: "default",
      onConfirm: () => {
        changeRoleMutation.mutate({ userId, role: newRole })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleBanToggle = (user: User) => {
    const isBanning = user.isActive
    setConfirmDialog({
      open: true,
      title: isBanning ? t("banConfirmTitle") : t("unbanConfirmTitle"),
      description: isBanning ? t("banConfirmDesc") : t("unbanConfirmDesc"),
      variant: isBanning ? "destructive" : "default",
      onConfirm: () => {
        toggleBanMutation.mutate({ userId: user._id, isActive: !user.isActive })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleConfirmUser = (user: User) => {
    const userId = user._id ?? (user as { id?: string }).id
    if (!userId) {
      toast.error("Cannot confirm user: missing user ID")
      return
    }
    setConfirmDialog({
      open: true,
      title: t("confirmUserTitle"),
      description: t("confirmUserDesc"),
      variant: "default",
      pendingId: userId,
      onConfirm: () => {
        confirmUserMutation.mutate(userId)
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleDeleteUser = (user: User) => {
    const userId = user._id ?? (user as { id?: string }).id
    if (!userId) {
      toast.error("Cannot delete user: missing user ID")
      return
    }
    setConfirmDialog({
      open: true,
      title: t("deleteConfirmTitle"),
      description: t("deleteConfirmDesc"),
      variant: "destructive",
      pendingId: userId,
      onConfirm: () => {
        deleteUserMutation.mutate(userId)
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleApproveDriver = (user: User) => {
    const userId = user._id ?? (user as { id?: string }).id
    if (!userId) return

    const approving = !user.isDriverApproved
    setConfirmDialog({
      open: true,
      title: approving ? t("approveDriverTitle") : t("rejectDriverTitle"),
      description: approving ? t("approveDriverDesc") : t("rejectDriverDesc"),
      variant: approving ? "default" : "destructive",
      pendingId: userId,
      onConfirm: () => {
        approveDriverMutation.mutate({ userId, approved: approving })
        setConfirmDialog((prev) => ({ ...prev, open: false }))
      },
    })
  }

  const handleRowClick = (user: User) => {
    const userId = user._id ?? (user as { id?: string }).id
    if (userId) navigate(`/users/${userId}`)
  }

  // Table columns
  const columns: Column<User>[] = [
    {
      key: "name",
      header: t("name"),
      cell: (user) => (
        <div className="flex items-center gap-3 py-1">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20">
            {user.name.charAt(0).toUpperCase()}
          </div>
          <div className="font-semibold text-foreground">{user.name}</div>
        </div>
      ),
    },
    {
      key: "email",
      header: t("email"),
      cell: (user) => <div className="text-muted-foreground font-medium">{user.email || "N/A"}</div>,
    },
    {
      key: "phone",
      header: t("phone"),
      cell: (user) => <div className="font-medium">{user.phoneNumber || "N/A"}</div>,
    },
    {
      key: "role",
      header: t("role"),
      cell: (user) => (
        <StatusBadge status={user.role} type="user" />
      ),
    },
    {
      key: "status",
      header: t("status"),
      cell: (user) => (
        <StatusBadge
          status={user.isActive ? "active" : "banned"}
          type="user"
        />
      ),
    },
    {
      key: "rating",
      header: t("rating"),
      cell: (user) => (
        <div className="flex items-center gap-1.5 font-medium">
          <span className="text-amber-500">⭐ {Number(user.rating ?? 0).toFixed(1)}</span>
          <span className="text-muted-foreground text-xs bg-muted px-1.5 rounded-full">({Number(user.totalRatings ?? 0)})</span>
        </div>
      ),
    },
    {
      key: "registered",
      header: t("registered"),
      cell: (user) => <div className="text-muted-foreground text-sm">{formatDate(user.createdAt)}</div>,
    },
    {
      key: "actions",
      header: "",
      className: "w-[50px]",
      cell: (user) => (
        <DropdownMenu>
          <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
            <Button variant="ghost" size="icon" className="hover:bg-muted/80 rounded-full transition-colors">
              <MoreHorizontal className="h-5 w-5 text-muted-foreground" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align={language === "ar" ? "start" : "end"} onClick={(e) => e.stopPropagation()} className="w-48 shadow-lg rounded-xl border-border/50 backdrop-blur-md bg-background/95">
            <div className="text-xs font-semibold px-2 py-1.5 text-muted-foreground uppercase tracking-wider">{t("roles")}</div>
            <DropdownMenuItem
              onClick={() => handleRoleChange(user._id, UserRole.PASSENGER)}
              disabled={user.role === UserRole.PASSENGER || changeRoleMutation.isPending}
              className="cursor-pointer font-medium"
            >
              <UserIcon className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
              {t("makePassenger")}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleRoleChange(user._id, UserRole.DRIVER)}
              disabled={user.role === UserRole.DRIVER || changeRoleMutation.isPending}
              className="cursor-pointer font-medium"
            >
              <UserCog className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
              {t("makeDriver")}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleRoleChange(user._id, UserRole.ADMIN)}
              disabled={user.role === UserRole.ADMIN || changeRoleMutation.isPending}
              className="cursor-pointer font-medium"
            >
              <Shield className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
              {t("makeAdmin")}
            </DropdownMenuItem>
            <div className="h-px bg-border my-1" />
            <DropdownMenuItem
              onClick={() => handleBanToggle(user)}
              disabled={toggleBanMutation.isPending}
              className={cn("cursor-pointer font-medium", user.isActive ? "text-rose-600 focus:text-rose-600 focus:bg-rose-50 dark:focus:bg-rose-950/30" : "text-emerald-600 focus:text-emerald-600 focus:bg-emerald-50 dark:focus:bg-emerald-950/30")}
            >
              {user.isActive ? (
                <>
                  <Ban className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
                  {t("banUser")}
                </>
              ) : (
                <>
                  <CheckCircle className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
                  {t("unbanUser")}
                </>
              )}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={() => handleConfirmUser(user)}
              disabled={
                confirmUserMutation.isPending ||
                (user.isActive && user.isPhoneVerified && user.isEmailVerified)
              }
              className="cursor-pointer font-medium text-blue-600 focus:text-blue-600 focus:bg-blue-50 dark:focus:bg-blue-950/30"
            >
              <UserCheck className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
              {t("confirmUser")}
            </DropdownMenuItem>
            {user.role === UserRole.DRIVER && (
              <DropdownMenuItem
                onClick={() => handleApproveDriver(user)}
                disabled={approveDriverMutation.isPending}
                className={cn(
                  "cursor-pointer font-medium",
                  user.isDriverApproved
                    ? "text-orange-600 focus:text-orange-600 focus:bg-orange-50 dark:focus:bg-orange-950/30"
                    : "text-emerald-600 focus:text-emerald-600 focus:bg-emerald-50 dark:focus:bg-emerald-950/30"
                )}
              >
                <Car className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
                {user.isDriverApproved ? t("rejectDriver") : t("approveDriver")}
              </DropdownMenuItem>
            )}
            <DropdownMenuItem
              onClick={() => handleDeleteUser(user)}
              disabled={deleteUserMutation.isPending || user.role === UserRole.ADMIN}
              className="cursor-pointer font-medium text-rose-600 focus:text-rose-600 focus:bg-rose-50 dark:focus:bg-rose-950/30"
            >
              <Trash2 className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
              {t("deleteUser")}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("usersManagement")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <Ban className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">{t("failedToLoadUsers")}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
            <UsersIcon className="w-8 h-8 text-primary" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">{t("usersTitle")}</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("usersSubtitle")}
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <CardTitle className="text-xl font-bold flex items-center">
              <Filter className={cn("w-5 h-5 text-primary", language === "ar" ? "ml-2" : "mr-2")} />
              {t("filterUsers")}
            </CardTitle>

            {/* Filters Row */}
            <div className="flex flex-col sm:flex-row w-full sm:w-auto gap-3">
              <div className="relative group min-w-[280px]">
                <Search className={cn("absolute top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground group-focus-within:text-primary transition-colors", language === "ar" ? "right-3" : "left-3")} />
                <Input
                  placeholder={t("searchPlaceholder")}
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  className={cn("bg-background/80 border-border/50 focus-visible:ring-primary/30 rounded-full shadow-sm", language === "ar" ? "pr-9" : "pl-9")}
                />
              </div>

              <div className="flex gap-3 w-full sm:w-auto">
                <Select
                  value={roleFilter || "all"}
                  onValueChange={(value) =>
                    updateSearchParams({ role: value === "all" ? null : value, page: "1" })
                  }
                >
                  <SelectTrigger className="w-full sm:w-[150px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                    <SelectValue placeholder={t("allRoles")} />
                  </SelectTrigger>
                  <SelectContent className="rounded-xl shadow-lg border-border/50">
                    <SelectItem value="all">{t("allRoles")}</SelectItem>
                    <SelectItem value={UserRole.PASSENGER}>{t("role_passenger")}</SelectItem>
                    <SelectItem value={UserRole.DRIVER}>{t("role_driver")}</SelectItem>
                    <SelectItem value={UserRole.ADMIN}>{t("role_admin")}</SelectItem>
                  </SelectContent>
                </Select>

                <Select
                  value={statusFilter || "all"}
                  onValueChange={(value) =>
                    updateSearchParams({ status: value === "all" ? null : value, page: "1" })
                  }
                >
                  <SelectTrigger className="w-full sm:w-[150px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                    <SelectValue placeholder={t("allStatus")} />
                  </SelectTrigger>
                  <SelectContent className="rounded-xl shadow-lg border-border/50">
                    <SelectItem value="all">{t("allStatus")}</SelectItem>
                    <SelectItem value="active">{t("active")}</SelectItem>
                    <SelectItem value="banned">{t("status_banned")}</SelectItem>
                  </SelectContent>
                </Select>
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
              emptyMessage={t("noUsersFound")}
              onRowClick={handleRowClick}
            />
          </div>
        </CardContent>
      </Card>

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
