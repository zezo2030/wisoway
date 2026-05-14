// T176 — ComplaintsPage
//
// Lists all user complaints submitted via POST /complaints.
// Admins can change the status (under_review → resolved / rejected) and
// optionally add internal notes.
//
// API: GET  /admin/complaints       (cursor-based)
//      PATCH /admin/complaints/:id  { status, adminNotes? }

import { useState } from "react"
import { useSearchParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
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
import { getComplaints, updateComplaint } from "@/api/admin"
import type { Complaint, ComplaintStatus } from "@/types/models"
import type { Column } from "@/components/data-table"
import { toast } from "sonner"
import { MessageSquareWarning, Clock, CheckCircle2, XCircle } from "lucide-react"

const STATUS_COLORS: Record<ComplaintStatus, string> = {
  pending:      "bg-yellow-50 text-yellow-700 border-yellow-200",
  under_review: "bg-blue-50 text-blue-700 border-blue-200",
  resolved:     "bg-green-50 text-green-700 border-green-200",
  rejected:     "bg-red-50 text-red-700 border-red-200",
}

const CATEGORY_LABELS: Record<string, string> = {
  SAFETY:           "Safety",
  PAYMENT:          "Payment",
  VEHICLE_CONDITION: "Vehicle Condition",
  DRIVER_BEHAVIOR:  "Driver Behavior",
  APP_ISSUE:        "App Issue",
  OTHER:            "Other",
}

interface ReviewState {
  open: boolean
  complaint: Complaint | null
  status: ComplaintStatus
  adminNotes: string
}

export default function ComplaintsPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()

  const page  = parseInt(searchParams.get("page")   || "1", 10)
  const status = (searchParams.get("status") || "") as ComplaintStatus | ""

  const [review, setReview] = useState<ReviewState>({
    open: false,
    complaint: null,
    status: "under_review",
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
    queryKey: [QUERY_KEYS.COMPLAINTS.LIST, { page, status }],
    queryFn: () => getComplaints({ page, limit: 20, ...(status ? { status } : {}) }),
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: { status: ComplaintStatus; adminNotes?: string } }) =>
      updateComplaint(id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.COMPLAINTS.LIST] })
      toast.success("Complaint updated")
      setReview((s) => ({ ...s, open: false }))
    },
    onError: () => toast.error("Failed to update complaint"),
  })

  function openReview(c: Complaint) {
    setReview({
      open: true,
      complaint: c,
      status: c.status === "pending" ? "under_review" : c.status,
      adminNotes: c.adminNotes ?? "",
    })
  }

  function submitReview() {
    if (!review.complaint) return
    updateMutation.mutate({
      id: review.complaint.id,
      payload: {
        status: review.status,
        adminNotes: review.adminNotes.trim() || undefined,
      },
    })
  }

  function getUserName(c: Complaint): string {
    if (typeof c.reporterId === "object" && c.reporterId !== null) {
      return (c.reporterId as { name?: string }).name ?? "—"
    }
    return c.reporterId as string ?? "—"
  }

  function getAgainstName(c: Complaint): string {
    if (c.againstUserId == null) return "—"
    if (typeof c.againstUserId === "object") {
      return (c.againstUserId as { name?: string }).name ?? "—"
    }
    return c.againstUserId as string
  }

  const columns: Column<Complaint>[] = [
    {
      key: "reporterId",
      header: "Reporter",
      cell: (c) => (
        <button
          className="text-primary hover:underline text-sm font-medium"
          onClick={(e) => {
            e.stopPropagation()
            const uid = typeof c.reporterId === "object"
              ? (c.reporterId as { id?: string; _id?: string }).id ?? (c.reporterId as { _id?: string })._id
              : c.reporterId
            if (uid) navigate(`/users/${uid}`)
          }}
        >
          {getUserName(c)}
        </button>
      ),
    },
    {
      key: "againstUserId",
      header: "Against",
      cell: (c) => (
        <span className="text-sm text-muted-foreground">{getAgainstName(c)}</span>
      ),
    },
    {
      key: "category",
      header: "Category",
      cell: (c) => (
        <span className="text-sm">{CATEGORY_LABELS[c.category] ?? c.category}</span>
      ),
    },
    {
      key: "status",
      header: "Status",
      cell: (c) => (
        <Badge variant="outline" className={STATUS_COLORS[c.status] ?? ""}>
          {c.status.replace("_", " ")}
        </Badge>
      ),
    },
    {
      key: "createdAt",
      header: "Submitted",
      cell: (c) => (
        <span className="text-sm text-muted-foreground">
          {new Date(c.createdAt).toLocaleDateString()}
        </span>
      ),
    },
    {
      key: "id",
      header: "Actions",
      cell: (c) =>
        c.status !== "resolved" && c.status !== "rejected" ? (
          <Button
            size="sm"
            variant="outline"
            onClick={(e) => { e.stopPropagation(); openReview(c) }}
          >
            Review
          </Button>
        ) : (
          <span className="text-xs text-muted-foreground capitalize">{c.status}</span>
        ),
    },
  ]

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Page Header */}
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-orange-100 dark:bg-orange-900/20">
          <MessageSquareWarning className="h-6 w-6 text-orange-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Complaints</h1>
          <p className="text-muted-foreground text-sm">Review and respond to user-submitted complaints</p>
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
                <SelectItem value="pending"><Clock className="inline h-3 w-3 mr-1" />Pending</SelectItem>
                <SelectItem value="under_review">Under Review</SelectItem>
                <SelectItem value="resolved"><CheckCircle2 className="inline h-3 w-3 mr-1" />Resolved</SelectItem>
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
            <DialogTitle>Review Complaint</DialogTitle>
          </DialogHeader>

          {review.complaint && (
            <div className="space-y-4">
              {/* Description preview */}
              <div className="rounded-lg bg-muted p-3 text-sm text-muted-foreground">
                <p className="font-medium text-foreground mb-1">
                  {CATEGORY_LABELS[review.complaint.category] ?? review.complaint.category}
                </p>
                <p className="line-clamp-4">{review.complaint.description}</p>
              </div>

              <div className="space-y-2">
                <Label>New Status</Label>
                <Select
                  value={review.status}
                  onValueChange={(v) => setReview((s) => ({ ...s, status: v as ComplaintStatus }))}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="under_review">Under Review</SelectItem>
                    <SelectItem value="resolved">Resolved</SelectItem>
                    <SelectItem value="rejected">Rejected</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Admin Notes (optional)</Label>
                <Textarea
                  rows={3}
                  placeholder="Internal note visible only to admins…"
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
              {updateMutation.isPending ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
