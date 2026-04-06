import { useMemo } from "react"
import { useNavigate, useSearchParams } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getAdminWallets } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { ROUTES } from "@/lib/constants"
import { cn, formatCurrency, formatDateTime } from "@/lib/utils"
import type { WalletAccountAdmin } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import { Wallet, AlertCircle, Clock } from "lucide-react"

export default function WalletsListPage() {
  const { t, language } = useLanguage()
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()

  const page = Number(searchParams.get("page") || "1")
  const limit = 20
  const roleFilter = searchParams.get("role") || "all"
  const accountTypeFilter = searchParams.get("accountType") || "all"
  const search = searchParams.get("search") || ""

  const updateSearchParams = (updates: Record<string, string | null>) => {
    const newParams = new URLSearchParams(searchParams)
    Object.entries(updates).forEach(([key, value]) => {
      if (!value) newParams.delete(key)
      else newParams.set(key, value)
    })
    if (Object.keys(updates).some((k) => k !== "page")) {
      newParams.set("page", "1")
    }
    setSearchParams(newParams)
  }

  const walletsQuery = useQuery({
    queryKey: ["admin-wallets", { page, limit, roleFilter, accountTypeFilter, search }],
    queryFn: () =>
      getAdminWallets({
        page,
        limit,
        role: roleFilter === "all" ? undefined : (roleFilter as "driver" | "passenger"),
        accountType:
          accountTypeFilter === "all" ? undefined : (accountTypeFilter as "driver" | "rider"),
        search: search || undefined,
      }),
  })

  const openWalletPage = (wallet: WalletAccountAdmin) => {
    navigate(`/wallets/${wallet.id}`)
  }

  const columns: Column<WalletAccountAdmin>[] = useMemo(() => {
    return [
      {
        key: "owner",
        header: language === "ar" ? "صاحب المحفظة" : "Owner",
        cell: (wallet) => (
          <div className="flex items-center gap-3 py-1">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20 flex-shrink-0">
              {(wallet.user?.name || "?").charAt(0).toUpperCase()}
            </div>
            <div>
              <div className="font-semibold text-foreground">{wallet.user?.name || "-"}</div>
              <div className="text-xs text-muted-foreground">
                {wallet.user?.email || wallet.user?.phoneNumber || "-"}
              </div>
            </div>
          </div>
        ),
      },
      {
        key: "role",
        header: language === "ar" ? "الدور" : "Role",
        cell: (wallet) => (
          <span className="text-xs font-semibold px-2 py-1 rounded-full bg-muted text-muted-foreground border border-border/40">
            {wallet.user?.role === "driver"
              ? language === "ar"
                ? "سائق"
                : "Driver"
              : wallet.user?.role === "passenger"
                ? language === "ar"
                  ? "راكب"
                  : "Passenger"
                : wallet.user?.role}
          </span>
        ),
      },
      {
        key: "accountType",
        header: language === "ar" ? "نوع المحفظة" : "Wallet Type",
        cell: (wallet) => (
          <span className="text-xs font-semibold px-2 py-1 rounded-full bg-muted text-muted-foreground border border-border/40">
            {wallet.accountType === "driver"
              ? language === "ar"
                ? "محفظة سائق"
                : "Driver Wallet"
              : language === "ar"
                ? "محفظة راكب"
                : "Rider Wallet"}
          </span>
        ),
      },
      {
        key: "balance",
        header: language === "ar" ? "الرصيد" : "Balance",
        cell: (wallet) => (
          <div className="font-black text-emerald-600 dark:text-emerald-400">
            {formatCurrency(Number(wallet.balance || 0), wallet.currency)}
          </div>
        ),
      },
      {
        key: "updatedAt",
        header: language === "ar" ? "آخر تحديث" : "Last Update",
        cell: (wallet) => (
          <div className="text-sm font-medium text-muted-foreground">
            {formatDateTime(wallet.updatedAt)}
          </div>
        ),
      },
      {
        key: "actions",
        header: language === "ar" ? "الفتح" : "Open",
        cell: () => (
          <span className="text-xs font-semibold text-primary">
            {language === "ar" ? "تفاصيل المحفظة" : "Wallet Details"}
          </span>
        ),
      },
    ]
  }, [language])

  if (walletsQuery.error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("walletsTitle")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">
            {language === "ar" ? "فشل تحميل المحافظ" : "Failed to load wallets"}
          </span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
            <Wallet className="w-8 h-8 text-primary" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
              {t("walletsTitle")}
            </h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {language === "ar"
                ? "إدارة محافظ الركاب والسائقين. اضغط على أي محفظة لفتح صفحة التفاصيل."
                : "Manage rider and driver wallets. Click any wallet to open its detail page."}
            </p>
          </div>
        </div>

        <Button
          variant="outline"
          className="rounded-xl border-border/50 shadow-sm font-semibold"
          onClick={() => navigate(ROUTES.PAYMENTS_PENDING)}
        >
          <Clock className={cn("w-4 h-4", language === "ar" ? "ml-2" : "mr-2")} />
          {t("pendingTopups")}
        </Button>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col lg:flex-row gap-3 lg:items-center justify-between">
            <div className="flex flex-wrap items-center gap-3">
              <Select
                value={roleFilter}
                onValueChange={(value) => updateSearchParams({ role: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[170px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={language === "ar" ? "الدور" : "Role"} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{language === "ar" ? "كل الأدوار" : "All Roles"}</SelectItem>
                  <SelectItem value="driver">{language === "ar" ? "السائقون" : "Drivers"}</SelectItem>
                  <SelectItem value="passenger">{language === "ar" ? "الركاب" : "Passengers"}</SelectItem>
                </SelectContent>
              </Select>

              <Select
                value={accountTypeFilter}
                onValueChange={(value) =>
                  updateSearchParams({ accountType: value === "all" ? null : value })
                }
              >
                <SelectTrigger className="w-[190px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={language === "ar" ? "نوع المحفظة" : "Wallet Type"} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{language === "ar" ? "كل المحافظ" : "All Wallets"}</SelectItem>
                  <SelectItem value="driver">{language === "ar" ? "محافظ السائقين" : "Driver Wallets"}</SelectItem>
                  <SelectItem value="rider">{language === "ar" ? "محافظ الركاب" : "Rider Wallets"}</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="w-full lg:w-[280px]">
              <Input
                value={search}
                onChange={(e) => updateSearchParams({ search: e.target.value || null })}
                placeholder={language === "ar" ? "بحث بالاسم أو البريد أو الهاتف" : "Search by name, email, or phone"}
                className="rounded-full bg-background/80 border-border/50"
              />
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <DataTable
              columns={columns}
              data={walletsQuery.data?.data || []}
              page={page}
              totalPages={walletsQuery.data?.meta.totalPages || 0}
              total={walletsQuery.data?.meta.total || 0}
              onPageChange={(newPage) => updateSearchParams({ page: String(newPage) })}
              pageSize={limit}
              loading={walletsQuery.isLoading}
              emptyMessage={language === "ar" ? "لا توجد محافظ مطابقة" : "No wallets found"}
              onRowClick={openWalletPage}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

