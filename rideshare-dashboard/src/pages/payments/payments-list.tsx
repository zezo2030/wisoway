// Payments List Page: All payments with filters
// T026: Implements all payments view with status, method, and type filters

import { useSearchParams } from "react-router-dom"
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
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatCurrency, getTripLocationName, cn } from "@/lib/utils"
import { PaymentStatus, PaymentMethod, PaymentType } from "@/types/enums"
import type { Payment, UserSummary, TripSummary } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import { CreditCard, Filter, AlertCircle, ArrowLeftRight } from "lucide-react"

// Type guard for populated fields
function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

function isPopulatedTrip(tripId: string | TripSummary | undefined): tripId is TripSummary {
  return typeof tripId === "object" && tripId !== null && "from" in tripId
}

export default function PaymentsListPage() {
  const { t, language } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = 20
  const statusFilter = searchParams.get("status") || ""
  const methodFilter = searchParams.get("method") || ""
  const typeFilter = searchParams.get("type") || ""

  // Fetch all payments
  const { data, isLoading, error } = useQuery({
    queryKey: [
      QUERY_KEYS.PAYMENTS.ALL,
      { page, limit, status: statusFilter, method: methodFilter, type: typeFilter },
    ],
    queryFn: () =>
      getAllPayments({
        page,
        limit,
        status: (statusFilter as PaymentStatus) || undefined,
        method: (methodFilter as PaymentMethod) || undefined,
        paymentType: (typeFilter as PaymentType) || undefined,
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
    // Reset to page 1 when filters change
    if (Object.keys(updates).some((k) => k !== "page")) {
      newParams.set("page", "1")
    }
    setSearchParams(newParams)
  }

  const handlePageChange = (newPage: number) => {
    updateSearchParams({ page: String(newPage) })
  }

  // Table columns
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
                <div className="font-semibold text-foreground">{payment.userId.name}</div>
                <div className="text-xs font-medium text-muted-foreground">{payment.userId.email}</div>
              </div>
            </>
          ) : (
            <span className="text-muted-foreground font-mono text-xs">ID: {payment.userId}</span>
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
            <span className="text-muted-foreground font-mono text-xs">ID: {payment.tripId}</span>
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
      key: "method",
      header: t("paymentMethod"),
      cell: (payment) => <StatusBadge status={payment.method} type="payment" className="shadow-sm" />,
    },
    {
      key: "type",
      header: t("paymentType"),
      cell: (payment) => (
        <span className="text-xs font-semibold px-2 py-1 rounded-full bg-muted text-muted-foreground border border-border/40">
          {payment.paymentType === PaymentType.TRIP ? t("paymentType_trip") : t("paymentType_fee")}
        </span>
      ),
    },
    {
      key: "status",
      header: t("status"),
      cell: (payment) => <StatusBadge status={payment.status} type="payment" className="shadow-sm" />,
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
        <div className="max-w-[150px] truncate text-xs font-medium text-muted-foreground bg-muted/40 px-2 py-1 rounded-md border border-border/30" title={payment.adminNote || ""}>
          {payment.adminNote || "-"}
        </div>
      ),
    },
    {
      key: "date",
      header: t("date"),
      cell: (payment) => <div className="text-sm font-medium text-muted-foreground">{formatDate(payment.createdAt)}</div>,
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("nav_payments")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">{t("failedToFetchStats")}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
            <CreditCard className="w-8 h-8 text-primary" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">{t("allPayments")}</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("paymentsSubtitle")}
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col lg:flex-row gap-5 lg:items-center justify-between">
            <div className="flex items-center gap-4">
              <Tabs
                value="all"
                onValueChange={(value) => {
                  if (value === "pending") {
                    window.location.href = "/payments/pending"
                  }
                }}
                className="w-full sm:w-auto"
              >
                <TabsList className="bg-background/80 p-1.5 rounded-2xl border border-border/40 shadow-sm">
                  <TabsTrigger value="all" className="rounded-xl px-5 py-2 font-semibold text-sm transition-all flex-1">
                    {t("allTransactions")}
                  </TabsTrigger>
                  <TabsTrigger value="pending" className="rounded-xl px-5 py-2 font-semibold text-sm transition-all flex-1">
                    {t("pendingQueue")}
                  </TabsTrigger>
                </TabsList>
              </Tabs>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <div className="flex items-center text-sm font-semibold text-muted-foreground">
                <Filter className={cn("w-4 h-4", language === "ar" ? "ml-1.5" : "mr-1.5")} /> {t("filter")}:
              </div>
              <Select
                value={statusFilter || "all"}
                onValueChange={(value) => updateSearchParams({ status: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[140px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={t("allStatus")} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{t("allStatus")}</SelectItem>
                  <SelectItem value={PaymentStatus.PENDING}>{t("pending")}</SelectItem>
                  <SelectItem value={PaymentStatus.APPROVED}>{t("approved")}</SelectItem>
                  <SelectItem value={PaymentStatus.REJECTED}>{t("rejected")}</SelectItem>
                  <SelectItem value={PaymentStatus.REFUNDED}>{t("refunded")}</SelectItem>
                </SelectContent>
              </Select>

              <Select
                value={methodFilter || "all"}
                onValueChange={(value) => updateSearchParams({ method: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[140px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={t("allMethods")} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{t("allMethods")}</SelectItem>
                  <SelectItem value={PaymentMethod.WALLET}>Wallet</SelectItem>
                  <SelectItem value={PaymentMethod.PAYMOB}>Paymob</SelectItem>
                  <SelectItem value={PaymentMethod.MANUAL}>Manual</SelectItem>
                  <SelectItem value={PaymentMethod.COMMUNICATION_FEE}>{t("paymentType_fee")}</SelectItem>
                </SelectContent>
              </Select>

              <Select
                value={typeFilter || "all"}
                onValueChange={(value) => updateSearchParams({ type: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[140px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm px-4">
                  <SelectValue placeholder={t("allTypes")} />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">{t("allTypes")}</SelectItem>
                  <SelectItem value={PaymentType.TRIP}>{t("paymentType_trip")}</SelectItem>
                  <SelectItem value={PaymentType.COMMUNICATION_FEE}>{t("paymentType_fee")}</SelectItem>
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
              emptyMessage={t("noPaymentsFound")}
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
