// Wallets List Page: Wallet accounts management (drivers and passengers)

import { useSearchParams, useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getWallets } from "@/api/wallets"
import { DataTable, type Column } from "@/components/data-table"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Input } from "@/components/ui/input"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatCurrency, cn } from "@/lib/utils"
import { WalletAccountType } from "@/types/enums"
import type { WalletAccount, UserSummary } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import { Wallet, AlertCircle, Search } from "lucide-react"

function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

export default function WalletsListPage() {
  const { t, language } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = 20
  const accountTypeFilter = searchParams.get("accountType") || "all"
  const searchFilter = searchParams.get("search") || ""

  const { data, isLoading, error } = useQuery({
    queryKey: [
      QUERY_KEYS.WALLETS.ALL,
      { page, limit, accountType: accountTypeFilter, search: searchFilter },
    ],
    queryFn: () =>
      getWallets({
        page,
        limit,
        accountType: accountTypeFilter !== "all" ? (accountTypeFilter as WalletAccountType) : undefined,
        search: searchFilter || undefined,
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

  const handleSearchChange = (value: string) => {
    updateSearchParams({ search: value || null })
  }

  const columns: Column<WalletAccount>[] = [
    {
      key: "user",
      header: t("walletOwner"),
      cell: (wallet) => (
        <div className="flex items-center gap-3 py-1">
          {isPopulatedUser(wallet.userId) ? (
            <>
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20 flex-shrink-0">
                {wallet.userId.name.charAt(0).toUpperCase()}
              </div>
              <div>
                <div className="font-semibold text-foreground">
                  {wallet.userId.name}
                </div>
                <div className="text-xs font-medium text-muted-foreground">
                  {wallet.userId.email}
                </div>
              </div>
            </>
          ) : (
            <span className="text-muted-foreground font-mono text-xs">
              ID: {wallet.userId}
            </span>
          )}
        </div>
      ),
    },
    {
      key: "accountType",
      header: t("walletAccountType"),
      cell: (wallet) => (
        <span
          className={cn(
            "text-xs font-semibold px-2.5 py-1 rounded-full border",
            wallet.accountType === WalletAccountType.DRIVER
              ? "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/30 dark:text-blue-400 dark:border-blue-800"
              : wallet.accountType === WalletAccountType.RIDER
                ? "bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-950/30 dark:text-purple-400 dark:border-purple-800"
                : "bg-muted text-muted-foreground border-border/40"
          )}
        >
          {wallet.accountType === WalletAccountType.DRIVER
            ? t("nav_drivers")
            : wallet.accountType === WalletAccountType.RIDER
              ? t("nav_passengers")
              : "System"}
        </span>
      ),
    },
    {
      key: "balance",
      header: t("balance"),
      cell: (wallet) => {
        const amount = Number(wallet.balance)
        return (
          <div
            className={cn(
              "font-black text-base",
              amount > 0
                ? "text-emerald-600 dark:text-emerald-400"
                : "text-muted-foreground"
            )}
          >
            {formatCurrency(amount, wallet.currency)}
          </div>
        )
      },
    },
    {
      key: "currency",
      header: t("currency"),
      cell: (wallet) => (
        <span className="text-sm font-medium text-muted-foreground">
          {wallet.currency}
        </span>
      ),
    },
    {
      key: "isActive",
      header: t("status"),
      cell: (wallet) => (
        <span
          className={cn(
            "text-xs font-semibold px-2.5 py-1 rounded-full border",
            wallet.isActive
              ? "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/30 dark:text-emerald-400 dark:border-emerald-800"
              : "bg-red-50 text-red-700 border-red-200 dark:bg-red-950/30 dark:text-red-400 dark:border-red-800"
          )}
        >
          {wallet.isActive ? t("active") : t("inactive")}
        </span>
      ),
    },
    {
      key: "updatedAt",
      header: t("lastUpdated"),
      cell: (wallet) => (
        <div className="text-sm font-medium text-muted-foreground">
          {formatDate(wallet.updatedAt)}
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("walletsTitle")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">
            {t("noWalletsFound")}
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
              {t("walletsSubtitle")}
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col lg:flex-row gap-5 lg:items-center justify-between">
            <div className="flex flex-wrap items-center gap-3">
              <div className="relative">
                <Search className={cn("absolute top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground", language === "ar" ? "right-3" : "left-3")} />
                <Input
                  placeholder={t("searchPlaceholder")}
                  value={searchFilter}
                  onChange={(e) => handleSearchChange(e.target.value)}
                  className={cn(
                    "w-[260px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm",
                    language === "ar" ? "pr-9 pl-4" : "pl-9 pr-4"
                  )}
                />
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <Select
                value={accountTypeFilter}
                onValueChange={(value) =>
                  updateSearchParams({ accountType: value === "all" ? null : value })
                }
              >
                <SelectTrigger className="w-[180px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={t("walletAccountType")} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{t("allAccountTypes")}</SelectItem>
                  <SelectItem value={WalletAccountType.DRIVER}>
                    {t("nav_drivers")}
                  </SelectItem>
                  <SelectItem value={WalletAccountType.RIDER}>
                    {t("nav_passengers")}
                  </SelectItem>
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
              emptyMessage={t("noWalletsFound")}
              onRowClick={(wallet) => navigate(`/wallets/${wallet.id}`)}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
