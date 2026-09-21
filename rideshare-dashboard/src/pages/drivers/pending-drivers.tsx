import { useEffect, useState } from "react"
import { useNavigate, useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getPendingDrivers, approveDriver } from "@/api/admin"
import type { User } from "@/types/models"
import { DataTable, type Column } from "@/components/data-table"
import { SimpleStatusBadge } from "@/components/status-badge"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatPhone } from "@/lib/utils"
import {
  BadgeCheck,
  AlertCircle,
  Search,
  CheckCircle2,
  XCircle,
  Eye,
} from "lucide-react"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"
import { cn } from "@/lib/utils"

function getUserId(user: User): string {
  return (user as { id?: string }).id ?? user._id
}

export default function PendingDriversPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { t, language } = useLanguage()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const search = searchParams.get("search") || ""
  const limit = 20

  const [searchInput, setSearchInput] = useState(search)
  const [approveTarget, setApproveTarget] = useState<User | null>(null)
  const [rejectTarget, setRejectTarget] = useState<User | null>(null)

  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.PENDING_DRIVERS.LIST, { page, limit, search }],
    queryFn: () => getPendingDrivers({ page, limit, search: search || undefined }),
  })

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchInput !== search) {
        const p = new URLSearchParams(searchParams)
        if (searchInput) p.set("search", searchInput)
        else p.delete("search")
        p.set("page", "1")
        setSearchParams(p)
      }
    }, 300)
    return () => clearTimeout(timer)
  }, [searchInput, search, searchParams, setSearchParams])

  const reviewMutation = useMutation({
    mutationFn: ({ userId, approved }: { userId: string; approved: boolean }) =>
      approveDriver(userId, approved),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.PENDING_DRIVERS.LIST] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.USERS] })
      toast.success(variables.approved ? t("driverApproved") : t("driverRejected"))
      setApproveTarget(null)
      setRejectTarget(null)
    },
    onError: () => {
      toast.error(t("pendingDriversActionError"))
    },
  })

  const handlePageChange = (newPage: number) => {
    const p = new URLSearchParams(searchParams)
    p.set("page", String(newPage))
    setSearchParams(p)
  }

  const handleRowClick = (driver: User) => {
    navigate(`/users/${getUserId(driver)}`)
  }

  const columns: Column<User>[] = [
    {
      key: "name",
      header: t("name"),
      cell: (driver) => (
        <div className="flex items-center gap-3 py-1">
          <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20">
            {driver.name.charAt(0).toUpperCase()}
          </div>
          <div className="font-semibold text-foreground">{driver.name}</div>
        </div>
      ),
    },
    {
      key: "contact",
      header: t("pendingDriversContact"),
      cell: (driver) => (
        <div className="text-sm">
          <div className="text-muted-foreground font-medium">{driver.email || "N/A"}</div>
          <div className="font-medium" dir="ltr">
            {driver.phoneNumber ? formatPhone(driver.phoneNumber) : ""}
          </div>
        </div>
      ),
    },
    {
      key: "status",
      header: t("status"),
      cell: () => (
        <SimpleStatusBadge status="pending" variant="secondary" />
      ),
    },
    {
      key: "registered",
      header: t("registered"),
      cell: (driver) => (
        <div className="text-muted-foreground text-sm whitespace-nowrap">
          {formatDate(driver.createdAt)}
        </div>
      ),
    },
    {
      key: "actions",
      header: t("pendingDriversActions"),
      className: "w-[230px]",
      cell: (driver) => (
        <div onClick={(e) => e.stopPropagation()} className="flex items-center gap-1.5">
          <Button
            size="sm"
            variant="outline"
            className="text-xs font-semibold"
            onClick={() => navigate(`/users/${getUserId(driver)}`)}
          >
            <Eye className="h-3.5 w-3.5" />
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="text-xs font-semibold text-emerald-600 hover:text-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/30"
            onClick={() => setApproveTarget(driver)}
            disabled={reviewMutation.isPending}
          >
            <CheckCircle2 className={cn("h-3.5 w-3.5", language === "ar" ? "ml-1.5" : "mr-1.5")} />
            {t("approveDriver")}
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="text-xs font-semibold text-rose-600 hover:text-rose-700 hover:bg-rose-50 dark:hover:bg-rose-950/30"
            onClick={() => setRejectTarget(driver)}
            disabled={reviewMutation.isPending}
          >
            <XCircle className={cn("h-3.5 w-3.5", language === "ar" ? "ml-1.5" : "mr-1.5")} />
            {t("rejectDriver")}
          </Button>
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("pendingDriversTitle")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">{t("pendingDriversLoadError")}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-amber-500/10 p-3 rounded-2xl border border-amber-500/20 shadow-sm hidden sm:block">
            <BadgeCheck className="w-8 h-8 text-amber-500" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
              {t("pendingDriversTitle")}
            </h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("pendingDriversSubtitle")}
            </p>
          </div>
        </div>
        <div className="text-sm font-semibold bg-background/80 px-4 py-2 rounded-full border border-border/50 shadow-sm self-start md:self-auto">
          <span className="text-muted-foreground">{t("total")}:</span>{" "}
          <span className="text-foreground ml-1">{data?.meta?.total ?? 0}</span>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <CardTitle className="text-xl font-bold flex items-center">
              <BadgeCheck className={cn("w-5 h-5 text-amber-500", language === "ar" ? "ml-2" : "mr-2")} />
              {t("pendingDriversTitle")}
            </CardTitle>
            <div className="relative group w-full sm:w-[320px]">
              <Search
                className={cn(
                  "absolute top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground group-focus-within:text-primary transition-colors",
                  language === "ar" ? "right-3" : "left-3",
                )}
              />
              <Input
                placeholder={t("searchPlaceholder")}
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
                className={cn(
                  "bg-background/80 border-border/50 focus-visible:ring-primary/30 rounded-full shadow-sm",
                  language === "ar" ? "pr-9" : "pl-9",
                )}
              />
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <DataTable
              columns={columns}
              data={data?.data ?? []}
              page={page}
              totalPages={data?.meta.totalPages ?? 0}
              total={data?.meta.total ?? 0}
              onPageChange={handlePageChange}
              pageSize={limit}
              loading={isLoading}
              emptyMessage={t("pendingDriversEmpty")}
              onRowClick={handleRowClick}
            />
          </div>
        </CardContent>
      </Card>

      <ConfirmDialog
        open={approveTarget !== null}
        onOpenChange={(open) => {
          if (!open) setApproveTarget(null)
        }}
        title={t("approveDriverTitle")}
        description={t("approveDriverDesc")}
        confirmLabel={t("approveDriver")}
        onConfirm={() => {
          if (approveTarget) reviewMutation.mutate({ userId: getUserId(approveTarget), approved: true })
        }}
        loading={reviewMutation.isPending}
      />

      <ConfirmDialog
        open={rejectTarget !== null}
        onOpenChange={(open) => {
          if (!open) setRejectTarget(null)
        }}
        title={t("rejectDriverTitle")}
        description={t("rejectDriverDesc")}
        confirmLabel={t("rejectDriver")}
        variant="destructive"
        onConfirm={() => {
          if (rejectTarget) reviewMutation.mutate({ userId: getUserId(rejectTarget), approved: false })
        }}
        loading={reviewMutation.isPending}
      />
    </div>
  )
}
