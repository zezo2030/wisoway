// T177 — RefundsPage
//
// Lists all refund requests submitted via POST /refund-requests.
// Admins can update the status (pending → approved / rejected) and add notes.
//
// API: GET   /admin/refund-requests      (paginated)
//      PATCH /admin/refund-requests/:id  { status, adminNotes? }

import { useState } from "react"
import { useSearchParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { ReceiptText, CheckCircle2, XCircle } from "lucide-react"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { DataTable } from "@/components/data-table"
import { QUERY_KEYS } from "@/lib/constants"
import { getRefundRequests, updateRefundRequest } from "@/api/admin"
import type { RefundRequest, RefundRequestStatus } from "@/types/models"
import type { Column } from "@/components/data-table"

const STATUS_COLORS: Record<RefundRequestStatus, string> = {
  pending:  "bg-yellow-50 text-yellow-700 border-yellow-200",
  approved: "bg-green-50 text-green-700 border-green-200",
  rejected: "bg-red-50 text-red-700 border-red-200",
}

interface ReviewState {
  open: boolean
  refund: RefundRequest | null
  status: RefundRequestStatus
  adminNotes: string
}

export default function RefundsPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()

  const page   = parseInt(searchParams.get("page")   || "1", 10)
  const status = (searchParams.get("status") || "") as RefundRequestStatus | ""

  const [review, setReview] = useState<ReviewState>({
    open: false,
    refund: null,
    status: "pending",
    adminNotes: "",
  })

  function updateParams(updates: Record<string, string>) {
    const next = new URLSearchParams(searchParams)
    Object.entries(updates).forEach(([k, v]) => {
      if (v) next.set(k, v)
      else next.delete(k)
    })
    setSearchParams(next)
  }

  const { data, isLoading } = useQuery({
    queryKey: [QUERY_KEYS.REFUNDS.LIST, { page, status }],
    queryFn: () => getRefundRequests({ page, limit: 20, ...(status ? { status } : {}) }),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: { status: RefundRequestStatus; adminNotes?: string } }) =>
      updateRefundRequest(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.REFUNDS.LIST] })
      toast.success("Refund request updated")
      setReview((s) => ({ ...s, open: false }))
    },
    onError: () => toast.error("Failed to update refund request"),
  })

  function openReview(r: RefundRequest) {
    setReview({
      open: true,
      refund: r,
      status: r.status === "pending" ? "approved" : r.status,
      adminNotes: r.adminNotes ?? "",
    })
  }

  function submitReview() {
    if (!review.refund) return
    updateMutation.mutate({
      id: review.refund.id,
      payload: {
        status: review.status,
        adminNotes: review.adminNotes.trim() || undefined,
      },
    })
  }

  function getUserName(r: RefundRequest): string {
    if (typeof r.userId === "object" && r.userId !== null) {
      return (r.userId as { name?: string }).name ?? "—"
    }
    return r.userId as string ?? "—"
  }

  const columns: Column<RefundRequest>[] = [
    {
      key: "userId",
      header: "User",
      cell: (r) => (
        <button
          className="text-primary hover:underline text-sm font-medium"
          onClick={(e) => {
            e.stopPropagation()
            const uid = typeof r.userId === "object"
              ? (r.userId as { id?: string; _id?: string }).id ?? (r.userId as { _id?: string })._id
              : r.userId
            if (uid) navigate(`/users/${uid}`)
          }}
        >
          {getUserName(r)}
        </button>
      ),
    },
    {
      key: "bookingId",
      header: "Booking",
      cell: (r) => (
        <span className="text-sm font-mono text-muted-foreground">
          {typeof r.bookingId === "object"
            ? (r.bookingId as { id?: string })?.id?.slice(-8) ?? "—"
            : (r.bookingId as string)?.slice(-8) ?? "—"}
        </span>
      ),
    },
    {
      key: "reason",
      header: "Reason",
      cell: (r) => (
        <span className="text-sm line-clamp-2 max-w-xs">{r.reason}</span>
      ),
    },
    {
      key: "status",
      header: "Status",
      cell: (r) => (
        <Badge variant="outline" className={STATUS_COLORS[r.status] ?? ""}>
          {r.status}
        </Badge>
      ),
    },
    {
      key: "whatsappContactedAt",
      header: "WA Contacted",
      cell: (r) => (
        <span className="text-sm text-muted-foreground">
          {r.whatsappContactedAt
            ? new Date(r.whatsappContactedAt).toLocaleDateString()
            : "—"}
        </span>
      ),
    },
    {
      key: "createdAt",
      header: "Submitted",
      cell: (r) => (
        <span className="text-sm text-muted-foreground">
          {new Date(r.createdAt).toLocaleDateString()}
        </span>
      ),
    },
    {
      key: "id",
      header: "Actions",
      cell: (r) =>
        r.status === "pending" ? (
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              className="text-green-700 border-green-200 hover:bg-green-50"
              onClick={(e) => { e.stopPropagation(); openReview(r) }}
            >
              <CheckCircle2 className="h-4 w-4 mr-1" />
              Review
            </Button>
          </div>
        ) : (
          <span className="text-xs text-muted-foreground capitalize">{r.status}</span>
        ),
    },
  ]

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Page Header */}
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-emerald-100 dark:bg-emerald-900/20">
          <ReceiptText className="h-6 w-6 text-emerald-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Refund Requests</h1>
          <p className="text-muted-foreground text-sm">Manage passenger refund requests</p>
        </div>
      </div>

      {/* Filters + Table */}
      <Card>
        <CardHeader className="pb-4">
          <div className="flex flex-wrap gap-3">
            <Select
              value={status || "all"}
              onValueChange={(v) => updateParams({ status: v === "all" ? "" : v, page: "1" })}
            >
              <SelectTrigger className="w-44">
                <SelectValue placeholder="All statuses" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All statuses</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="approved"><CheckCircle2 className="inline h-3 w-3 mr-1" />Approved</SelectItem>
                <SelectItem value="rejected"><XCircle className="inline h-3 w-3 mr-1" />Rejected</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          <DataTable
            columns={columns}
            data={data?.data ?? []}
            page={page}
            totalPages={data?.meta?.totalPages ?? 0}
            total={data?.meta?.total ?? 0}
            onPageChange={(p) => updateParams({ page: String(p) })}
            loading={isLoading}
          />
        </CardContent>
      </Card>

      {/* Review Dialog */}
      <Dialog open={review.open} onOpenChange={(o) => !o && setReview((s) => ({ ...s, open: false }))}>
        <DialogContent className="max-w-lg">
          <DialogHeader>
            <DialogTitle>Review Refund Request</DialogTitle>
          </DialogHeader>

          {review.refund && (
            <div className="space-y-4">
              {/* Reason preview */}
              <div className="rounded-lg bg-muted p-3 text-sm text-muted-foreground">
                <p className="font-medium text-foreground mb-1">Passenger reason</p>
                <p className="line-clamp-4">{review.refund.reason}</p>
              </div>

              <div className="space-y-2">
                <Label>Decision</Label>
                <Select
                  value={review.status}
                  onValueChange={(v) => setReview((s) => ({ ...s, status: v as RefundRequestStatus }))}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="approved">Approved</SelectItem>
                    <SelectItem value="rejected">Rejected</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Admin Notes (optional)</Label>
                <Textarea
                  rows={3}
                  placeholder="Internal note…"
                  value={review.adminNotes}
                  onChange={(e) => setReview((s) => ({ ...s, adminNotes: e.target.value }))}
                />
              </div>
            </div>
          )}

          <DialogFooter>
            <Button variant="outline" onClick={() => setReview((s) => ({ ...s, open: false }))}>
              Cancel
            </Button>
            <Button onClick={submitReview} disabled={updateMutation.isPending}>
              {updateMutation.isPending ? "Saving…" : "Save Decision"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
