// Wallets List Page: Wallet transactions (top-ups and trip charges)

import { useSearchParams, useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { getAllPayments } from "@/api/payments"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ImagePreview } from "@/components/image-preview"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Button } from "@/components/ui/button"
import { QUERY_KEYS, ROUTES } from "@/lib/constants"
import { formatDate, formatCurrency, getTripLocationName, cn } from "@/lib/utils"
import { PaymentType } from "@/types/enums"
import type { Payment, UserSummary, TripSummary } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import { Wallet, AlertCircle, ArrowLeftRight, Clock } from "lucide-react"

function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

function isPopulatedTrip(
  tripId: string | TripSummary | undefined
): tripId is TripSummary {
  return typeof tripId === "object" && tripId !== null && "from" in tripId
}

export default function WalletsListPage() {
  const { t, language } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = 20
  const typeFilter = searchParams.get("type") || "all"

  const { data, isLoading, error } = useQuery({
    queryKey: [
      QUERY_KEYS.PAYMENTS.ALL,
      "wallets",
      { page, limit, type: typeFilter },
    ],
    queryFn: () =>
      getAllPayments({
        page,
        limit,
        walletOnly: typeFilter === "all",
        paymentType:
          typeFilter !== "all" ? (typeFilter as PaymentType) : undefined,
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

  const columns: Column<Payment>[] = [
    {
      key: "user",
      header: t("passenger"),
      cell: (payment) => (
        <div className="flex items-center gap-3 py-1">
          {isPopulatedUser(payment.userId) ? (
            <>
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20 flex-shrink-0">
                {payment.userId.name.charAt(0).toUpperCase()}
              </div>
              <div>
                <div className="font-semibold text-foreground">
                  {payment.userId.name}
                </div>
                <div className="text-xs font-medium text-muted-foreground">
                  {payment.userId.email}
                </div>
              </div>
            </>
          ) : (
            <span className="text-muted-foreground font-mono text-xs">
              ID: {payment.userId}
            </span>
          )}
        </div>
      ),
    },
    {
      key: "trip",
      header: t("nav_trips"),
      cell: (payment) => (
        <div>
          {isPopulatedTrip(payment.tripId) ? (
            <>
              <div className="font-medium flex items-center gap-1">
                {getTripLocationName(payment.tripId as unknown as Record<string, unknown>, "from")}
                <ArrowLeftRight className="w-3 h-3 text-muted-foreground" />
                {getTripLocationName(payment.tripId as unknown as Record<string, unknown>, "to")}
              </div>
              <div className="text-xs font-medium text-muted-foreground mt-0.5">
                {formatDate(payment.tripId.departureTime)}
              </div>
            </>
          ) : payment.tripId ? (
            <span className="text-muted-foreground font-mono text-xs">
              ID: {payment.tripId}
            </span>
          ) : (
            <span className="text-muted-foreground italic">N/A</span>
          )}
        </div>
      ),
    },
    {
      key: "amount",
      header: t("amount"),
      cell: (payment) => (
        <div className="font-black text-emerald-600 dark:text-emerald-400">
          {formatCurrency(payment.amount, payment.currency)}
        </div>
      ),
    },
    {
      key: "type",
      header: t("paymentType"),
      cell: (payment) => (
        <span className="text-xs font-semibold px-2 py-1 rounded-full bg-muted text-muted-foreground border border-border/40 object-cover">
          {payment.paymentType === PaymentType.WALLET_TOPUP ? t("walletTopup") : t("walletTripCharge")}
        </span>
      ),
    },
    {
      key: "status",
      header: t("status"),
      cell: (payment) => (
        <StatusBadge status={payment.status} type="payment" className="shadow-sm" />
      ),
    },
    {
      key: "proof",
      header: t("proof"),
      cell: (payment) => (
        <ImagePreview
          imageUrl={payment.proofImageUrl}
          alt={t("proof")}
          thumbnailClassName="h-10 w-10 sm:h-12 sm:w-12 rounded-lg shadow-sm border border-border/50 object-cover"
        />
      ),
    },
    {
      key: "adminNote",
      header: t("adminNote"),
      cell: (payment) => (
        <div
          className="max-w-[150px] truncate text-xs font-medium text-muted-foreground bg-muted/40 px-2 py-1 rounded-md border border-border/30"
          title={payment.adminNote || ""}
        >
          {payment.adminNote || "-"}
        </div>
      ),
    },
    {
      key: "date",
      header: t("date"),
      cell: (payment) => (
        <div className="text-sm font-medium text-muted-foreground">
          {formatDate(payment.createdAt)}
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
            {t("noWalletTransactionsFound")}
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
            <div className="flex items-center gap-4">
              <Button
                variant="outline"
                className="rounded-xl border-border/50 shadow-sm font-semibold"
                onClick={() => navigate(ROUTES.PAYMENTS_PENDING)}
              >
                <Clock className={cn("w-4 h-4", language === "ar" ? "ml-2" : "mr-2")} />
                {t("pendingTopups")}
              </Button>
            </div>
            <div className="flex flex-wrap items-center gap-3">
              <Select
                value={typeFilter}
                onValueChange={(value) =>
                  updateSearchParams({ type: value === "all" ? null : value })
                }
              >
                <SelectTrigger className="w-[180px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={t("transactionType")} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{t("allWalletTransactions")}</SelectItem>
                  <SelectItem value={PaymentType.WALLET_TOPUP}>
                    {t("walletTopup")}
                  </SelectItem>
                  <SelectItem value={PaymentType.WALLET_TRIP_CHARGE}>
                    {t("walletTripCharge")}
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
              emptyMessage={t("noWalletTransactionsFound")}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
