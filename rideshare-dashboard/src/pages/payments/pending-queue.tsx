// Pending Payments Queue Page: Payment approval workflow
// T025: Implements pending queue with approve/reject actions and proof preview

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getPendingPayments, approvePayment, rejectPayment } from "@/api/payments"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ImagePreview } from "@/components/image-preview"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Textarea } from "@/components/ui/textarea"
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL } from "@/lib/constants"
import { formatDate, formatCurrency, getPaymentTypeLabel, cn } from "@/lib/utils"
import type { Payment, UserSummary, TripSummary } from "@/types/models"
import { CheckCircle, XCircle, AlertCircle, ArrowLeftRight, Clock, Info, User } from "lucide-react"
import { toast } from "sonner"

// Type guard for populated fields
function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

function isPopulatedTrip(tripId: string | TripSummary | undefined): tripId is TripSummary {
  return typeof tripId === "object" && tripId !== null && "from" in tripId
}

export default function PendingQueuePage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = 20

  // Dialog states
  const [actionDialog, setActionDialog] = useState<{
    open: boolean
    payment: Payment | null
    action: "approve" | "reject" | null
    adminNote: string
  }>({
    open: false,
    payment: null,
    action: null,
    adminNote: "",
  })

  // Fetch pending payments
  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.PAYMENTS.PENDING, { page, limit }],
    queryFn: () => getPendingPayments({ page, limit }),
    refetchInterval: DASHBOARD_REFRESH_INTERVAL,
  })

  // Approve mutation
  const approveMutation = useMutation({
    mutationFn: ({ paymentId, adminNote }: { paymentId: string; adminNote?: string }) =>
      approvePayment(paymentId, adminNote),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.PAYMENTS.PENDING] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS] })
      toast.success("Payment approved successfully")
      setActionDialog({ open: false, payment: null, action: null, adminNote: "" })
    },
    onError: (error: Error) => {
      if (error.message.includes("already processed")) {
        toast.error("Payment already processed")
      } else {
        toast.error("Failed to approve payment")
      }
    },
  })

  // Reject mutation
  const rejectMutation = useMutation({
    mutationFn: ({ paymentId, adminNote }: { paymentId: string; adminNote?: string }) =>
      rejectPayment(paymentId, adminNote),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.PAYMENTS.PENDING] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS] })
      toast.success("Payment rejected successfully")
      setActionDialog({ open: false, payment: null, action: null, adminNote: "" })
    },
    onError: (error: Error) => {
      if (error.message.includes("already processed")) {
        toast.error("Payment already processed")
      } else {
        toast.error("Failed to reject payment")
      }
    },
  })

  const handlePageChange = (newPage: number) => {
    const newParams = new URLSearchParams(searchParams)
    newParams.set("page", String(newPage))
    setSearchParams(newParams)
  }

  const openActionDialog = (payment: Payment, action: "approve" | "reject") => {
    setActionDialog({
      open: true,
      payment,
      action,
      adminNote: "",
    })
  }

  const handleConfirmAction = () => {
    if (!actionDialog.payment || !actionDialog.action) return

    const { payment, action, adminNote } = actionDialog

    if (action === "approve") {
      approveMutation.mutate({ paymentId: payment._id, adminNote: adminNote || undefined })
    } else {
      rejectMutation.mutate({ paymentId: payment._id, adminNote: adminNote || undefined })
    }
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
                {payment.tripId.from.name}
                <ArrowLeftRight className="w-3 h-3 text-muted-foreground" />
                {payment.tripId.to.name}
              </div>
              <div className="text-xs font-medium text-muted-foreground mt-0.5 flex flex-col sm:flex-row gap-1">
                <span className="bg-muted px-1.5 py-0.5 rounded border border-border/40 inline-flex w-fit items-center">
                  <Clock className="w-3 h-3 mr-1 opacity-70" />
                  {formatDate(payment.tripId.departureTime)}
                </span>
              </div>
            </>
          ) : payment.tripId ? (
            <span className="text-muted-foreground font-mono text-xs">ID: {payment.tripId}</span>
          ) : (
            <span className="text-muted-foreground italic text-xs bg-muted px-2 py-1 rounded inline-flex">None Attached</span>
          )}
        </div>
      ),
    },
    {
      key: "amount",
      header: "Amount",
      cell: (payment) => (
        <div className="font-black text-lg text-emerald-600 dark:text-emerald-400">
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
        <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-muted text-muted-foreground border border-border/40">
          {getPaymentTypeLabel(payment.paymentType)}
        </span>
      ),
    },
    {
      key: "proof",
      header: "Proof Image",
      cell: (payment) => (
        <ImagePreview
          imageUrl={payment.proofImageUrl}
          alt="Payment proof"
          thumbnailClassName="h-14 w-14 rounded-xl shadow-md border-2 border-border object-cover cursor-zoom-in hover:scale-105 transition-transform"
        />
      ),
    },
    {
      key: "date",
      header: "Submitted",
      cell: (payment) => <div className="text-sm font-medium text-muted-foreground">{formatDate(payment.createdAt)}</div>,
    },
    {
      key: "actions",
      header: "Actions",
      className: "w-[170px]",
      cell: (payment) => (
        <div className="flex gap-2" onClick={(e) => e.stopPropagation()}>
          <Button
            size="sm"
            variant="default"
            className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs shadow-md shadow-emerald-600/20"
            onClick={() => openActionDialog(payment, "approve")}
            disabled={approveMutation.isPending || rejectMutation.isPending}
          >
            <CheckCircle className="mr-1.5 h-3.5 w-3.5" />
            Approve
          </Button>
          <Button
            size="sm"
            variant="destructive"
            className="font-semibold text-xs shadow-md shadow-rose-600/20"
            onClick={() => openActionDialog(payment, "reject")}
            disabled={approveMutation.isPending || rejectMutation.isPending}
          >
            <XCircle className="mr-1.5 h-3.5 w-3.5" />
            Reject
          </Button>
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">Pending Queue</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className="w-6 h-6 mr-3" />
          <span className="font-semibold text-lg">Failed to load pending payments. Please try again.</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-amber-500/10 p-3 rounded-2xl border border-amber-500/20 shadow-sm hidden sm:block">
            <Clock className="w-8 h-8 text-amber-500" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">Pending Actions</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              Review and process manual payments requiring administrator approval.
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col lg:flex-row gap-5 lg:items-center justify-between">
            <div className="flex items-center gap-4">
              <Tabs
                value="pending"
                onValueChange={(value) => {
                  if (value === "all") {
                    window.location.href = "/payments"
                  }
                }}
                className="w-full sm:w-auto"
              >
                <TabsList className="bg-background/80 p-1.5 rounded-2xl border border-border/40 shadow-sm">
                  <TabsTrigger value="all" className="rounded-xl px-5 py-2 font-semibold text-sm transition-all flex-1">
                    All Transactions
                  </TabsTrigger>
                  <TabsTrigger value="pending" className="rounded-xl px-5 py-2 font-semibold text-sm transition-all flex-1 text-amber-600 data-[state=active]:text-amber-600 bg-amber-50/50">
                    Pending Queue <span className="ml-1.5 bg-amber-500/20 text-amber-700 px-1.5 py-0.5 rounded-full text-xs">{data?.meta.total || 0}</span>
                  </TabsTrigger>
                </TabsList>
              </Tabs>
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
              emptyMessage="No pending payments require approval right now. Awesome!"
            />
          </div>
        </CardContent>
      </Card>

      {/* Action Dialog with Admin Note */}
      <Dialog
        open={actionDialog.open}
        onOpenChange={(open) => {
          if (!open) {
            setActionDialog({ open: false, payment: null, action: null, adminNote: "" })
          }
        }}
      >
        <DialogContent className="sm:max-w-[450px] shadow-2xl rounded-2xl border-border/60 bg-background/95 backdrop-blur-3xl overflow-hidden p-0">

          <div className={cn(
            "h-2 w-full",
            actionDialog.action === "approve" ? "bg-emerald-500" : "bg-rose-500"
          )} />

          <div className="p-6 pt-5">
            <DialogHeader className="mb-4">
              <DialogTitle className="flex items-center text-xl">
                {actionDialog.action === "approve" ? (
                  <><CheckCircle className="w-5 h-5 mr-2 text-emerald-500" /> Confirm Approval</>
                ) : (
                  <><XCircle className="w-5 h-5 mr-2 text-rose-500" /> Confirm Rejection</>
                )}
              </DialogTitle>
            </DialogHeader>

            <div className="space-y-5">
              {actionDialog.payment && (
                <div className="rounded-xl bg-muted/50 p-4 border border-border/40 space-y-3">
                  <div className="flex justify-between items-center border-b border-border/40 pb-3">
                    <span className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">Requested Amount</span>
                    <span className="font-black text-xl text-foreground bg-background px-2 py-0.5 rounded-md shadow-sm border border-border/30">
                      {formatCurrency(actionDialog.payment.amount, actionDialog.payment.currency)}
                    </span>
                  </div>

                  <div className="flex flex-col gap-1.5 pt-1">
                    <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider">Submitted By</span>
                    <div className="flex items-center gap-2 bg-background p-2 rounded-lg border border-border/30 shadow-sm">
                      <div className="bg-primary/10 w-7 h-7 rounded-sm flex items-center justify-center">
                        <User className="w-3.5 h-3.5 text-primary" />
                      </div>
                      <span className="font-semibold text-sm">
                        {isPopulatedUser(actionDialog.payment.userId)
                          ? actionDialog.payment.userId.name
                          : actionDialog.payment.userId}
                      </span>
                    </div>
                  </div>
                </div>
              )}

              <div className="space-y-2">
                <label className="text-sm font-bold flex items-center text-foreground/90">
                  <Info className="w-4 h-4 mr-1.5 text-primary" />
                  Admin Note <span className="text-muted-foreground ml-1.5 text-xs font-normal">(Optional)</span>
                </label>
                <Textarea
                  placeholder="Explain why this decision was made..."
                  value={actionDialog.adminNote}
                  className="resize-none h-24 bg-background/50 border-border/50 focus-visible:ring-primary/40 shadow-inner rounded-xl"
                  onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
                    setActionDialog((prev) => ({ ...prev, adminNote: e.target.value }))
                  }
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <Button
                  variant="outline"
                  className="rounded-xl shadow-sm border-border hover:bg-muted font-semibold px-5"
                  onClick={() =>
                    setActionDialog({ open: false, payment: null, action: null, adminNote: "" })
                  }
                >
                  Cancel
                </Button>
                <Button
                  variant={actionDialog.action === "approve" ? "default" : "destructive"}
                  onClick={handleConfirmAction}
                  disabled={approveMutation.isPending || rejectMutation.isPending}
                  className={cn(
                    "rounded-xl shadow-md font-bold px-6",
                    actionDialog.action === "approve"
                      ? "bg-emerald-600 hover:bg-emerald-700 shadow-emerald-600/20"
                      : "shadow-rose-600/20"
                  )}
                >
                  {approveMutation.isPending || rejectMutation.isPending
                    ? "Processing..."
                    : actionDialog.action === "approve"
                      ? "Confirm Approval"
                      : "Confirm Rejection"}
                </Button>
              </div>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}
