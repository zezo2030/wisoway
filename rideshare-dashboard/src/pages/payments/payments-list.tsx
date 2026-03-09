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
import { formatDate, formatCurrency, getPaymentTypeLabel, getTripLocationName } from "@/lib/utils"
import { PaymentStatus, PaymentMethod, PaymentType } from "@/types/enums"
import type { Payment, UserSummary, TripSummary } from "@/types/models"
import { CreditCard, Filter, AlertCircle, ArrowLeftRight } from "lucide-react"

// Type guard for populated fields
function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

function isPopulatedTrip(tripId: string | TripSummary | undefined): tripId is TripSummary {
  return typeof tripId === "object" && tripId !== null && "from" in tripId
}

export default function PaymentsListPage() {
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
      header: "User",
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
      header: "Trip",
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
      header: "Amount",
      cell: (payment) => (
        <div className="font-black text-emerald-600 dark:text-emerald-400">
          {formatCurrency(payment.amount, payment.currency)}
        </div>
      ),
    },
    {
      key: "method",
      header: "Method",
      cell: (payment) => <StatusBadge status={payment.method} type="payment" className="shadow-sm" />,
    },
    {
      key: "type",
      header: "Type",
      cell: (payment) => (
        <span className="text-xs font-semibold px-2 py-1 rounded-full bg-muted text-muted-foreground border border-border/40 object-cover">
          {getPaymentTypeLabel(payment.paymentType)}
        </span>
      ),
    },
    {
      key: "status",
      header: "Status",
      cell: (payment) => <StatusBadge status={payment.status} type="payment" className="shadow-sm" />,
    },
    {
      key: "proof",
      header: "Proof",
      cell: (payment) => (
        <ImagePreview
          imageUrl={payment.proofImageUrl}
          alt="Payment proof"
          thumbnailClassName="h-10 w-10 sm:h-12 sm:w-12 rounded-lg shadow-sm border border-border/50 object-cover"
        />
      ),
    },
    {
      key: "adminNote",
      header: "Admin Note",
      cell: (payment) => (
        <div className="max-w-[150px] truncate text-xs font-medium text-muted-foreground bg-muted/40 px-2 py-1 rounded-md border border-border/30" title={payment.adminNote || ""}>
          {payment.adminNote || "-"}
        </div>
      ),
    },
    {
      key: "date",
      header: "Date",
      cell: (payment) => <div className="text-sm font-medium text-muted-foreground">{formatDate(payment.createdAt)}</div>,
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">Payments</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className="w-6 h-6 mr-3" />
          <span className="font-semibold text-lg">Failed to load payments. Please try again.</span>
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
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">All Payments</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              View, filter, and track all payment transactions across the platform.
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
                    All Transactions
                  </TabsTrigger>
                  <TabsTrigger value="pending" className="rounded-xl px-5 py-2 font-semibold text-sm transition-all flex-1">
                    Pending Queue
                  </TabsTrigger>
                </TabsList>
              </Tabs>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <div className="flex items-center text-sm font-semibold text-muted-foreground mr-1">
                <Filter className="w-4 h-4 mr-1.5" /> Filters:
              </div>
              <Select
                value={statusFilter || "all"}
                onValueChange={(value) => updateSearchParams({ status: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[140px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm">
                  <SelectValue placeholder="All Status" />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">All Status</SelectItem>
                  <SelectItem value={PaymentStatus.PENDING}>Pending</SelectItem>
                  <SelectItem value={PaymentStatus.APPROVED}>Approved</SelectItem>
                  <SelectItem value={PaymentStatus.REJECTED}>Rejected</SelectItem>
                  <SelectItem value={PaymentStatus.REFUNDED}>Refunded</SelectItem>
                </SelectContent>
              </Select>

              <Select
                value={methodFilter || "all"}
                onValueChange={(value) => updateSearchParams({ method: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[140px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm">
                  <SelectValue placeholder="All Methods" />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">All Methods</SelectItem>
                  <SelectItem value={PaymentMethod.STRIPE}>Stripe</SelectItem>
                  <SelectItem value={PaymentMethod.PAYMOB}>Paymob</SelectItem>
                  <SelectItem value={PaymentMethod.MANUAL}>Manual</SelectItem>
                  <SelectItem value={PaymentMethod.COMMUNICATION_FEE}>Communication Fee</SelectItem>
                </SelectContent>
              </Select>

              <Select
                value={typeFilter || "all"}
                onValueChange={(value) => updateSearchParams({ type: value === "all" ? null : value })}
              >
                <SelectTrigger className="w-[140px] bg-background/80 border-border/50 rounded-full font-medium shadow-sm">
                  <SelectValue placeholder="All Types" />
                </SelectTrigger>
                <SelectContent className="rounded-xl shadow-lg border-border/50">
                  <SelectItem value="all">All Types</SelectItem>
                  <SelectItem value={PaymentType.TRIP}>Trip</SelectItem>
                  <SelectItem value={PaymentType.COMMUNICATION_FEE}>Communication Fee</SelectItem>
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
              emptyMessage="No payments found matching criteria."
            />
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
