// Settlement Dialog: Audit trail viewer + admin-revert action (Phase 7 / T153)

import { useState } from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getSettlementAudits, adminRevertSettlement } from "@/api/admin"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate } from "@/lib/utils"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Textarea } from "@/components/ui/textarea"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { AlertCircle, CheckCircle2, Clock, RotateCcw, ShieldAlert } from "lucide-react"
import { toast } from "sonner"
import type { SettlementAudit } from "@/types/models"

interface SettlementDialogProps {
  bookingId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

const ACTION_META: Record<
  SettlementAudit["action"],
  { label: string; icon: React.ReactNode; variant: "default" | "secondary" | "destructive" }
> = {
  mark_paid: {
    label: "Marked Paid",
    icon: <CheckCircle2 className="h-3.5 w-3.5" />,
    variant: "default",
  },
  unmark_paid: {
    label: "Unmarked Paid",
    icon: <Clock className="h-3.5 w-3.5" />,
    variant: "secondary",
  },
  admin_revert: {
    label: "Admin Revert",
    icon: <ShieldAlert className="h-3.5 w-3.5" />,
    variant: "destructive",
  },
}

function isUserSummary(val: unknown): val is { name: string } {
  return typeof val === "object" && val !== null && "name" in val
}

export function SettlementDialog({ bookingId, open, onOpenChange }: SettlementDialogProps) {
  const queryClient = useQueryClient()
  const [revertReason, setRevertReason] = useState("")
  const [showRevertForm, setShowRevertForm] = useState(false)

  const { data: audits, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.SETTLEMENT.AUDITS, bookingId],
    queryFn: () => getSettlementAudits(bookingId),
    enabled: open,
  })

  const revertMutation = useMutation({
    mutationFn: () => adminRevertSettlement(bookingId, revertReason.trim() || undefined),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.SETTLEMENT.AUDITS, bookingId] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.BOOKINGS] })
      toast.success("Settlement reverted successfully")
      setShowRevertForm(false)
      setRevertReason("")
    },
    onError: () => {
      toast.error("Failed to revert settlement")
    },
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 text-primary" />
            Settlement Audit Trail
          </DialogTitle>
          <DialogDescription>
            View the settlement history for this booking and revert if needed.
          </DialogDescription>
        </DialogHeader>

        {/* Audit list */}
        <div className="max-h-72 overflow-y-auto space-y-3 py-1 pr-1">
          {isLoading && (
            <p className="text-sm text-muted-foreground text-center py-4">Loading…</p>
          )}
          {error && (
            <div className="flex items-center gap-2 text-destructive text-sm">
              <AlertCircle className="h-4 w-4 flex-shrink-0" />
              Failed to load audit trail.
            </div>
          )}
          {audits && audits.length === 0 && (
            <p className="text-sm text-muted-foreground text-center py-4">
              No settlement activity yet.
            </p>
          )}
          {audits?.map((entry) => {
            const meta = ACTION_META[entry.action]
            const actorName = isUserSummary(entry.actorId)
              ? entry.actorId.name
              : entry.actorId
            return (
              <div
                key={entry.id}
                className="flex items-start gap-3 rounded-lg border border-border/40 bg-muted/30 p-3"
              >
                <div className="mt-0.5 flex-shrink-0">
                  <Badge
                    variant={meta.variant}
                    className="flex items-center gap-1 text-xs font-semibold px-2 py-0.5"
                  >
                    {meta.icon}
                    {meta.label}
                  </Badge>
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-foreground truncate">{actorName}</p>
                  {entry.reason && (
                    <p className="text-xs text-muted-foreground mt-0.5 line-clamp-2">
                      {entry.reason}
                    </p>
                  )}
                  <p className="text-xs text-muted-foreground mt-1">
                    {formatDate(entry.createdAt)}
                  </p>
                </div>
              </div>
            )
          })}
        </div>

        <Separator />

        {/* Revert section */}
        {!showRevertForm ? (
          <Button
            variant="destructive"
            className="w-full font-semibold"
            onClick={() => setShowRevertForm(true)}
          >
            <RotateCcw className="mr-2 h-4 w-4" />
            Admin Revert Settlement
          </Button>
        ) : (
          <div className="space-y-3">
            <Label htmlFor="revert-reason" className="text-sm font-semibold">
              Reason (optional)
            </Label>
            <Textarea
              id="revert-reason"
              placeholder="Describe why you are reverting this settlement…"
              value={revertReason}
              onChange={(e) => setRevertReason(e.target.value)}
              className="resize-none"
              rows={3}
            />
            <div className="flex gap-2">
              <Button
                variant="destructive"
                className="flex-1 font-semibold"
                onClick={() => revertMutation.mutate()}
                disabled={revertMutation.isPending}
              >
                {revertMutation.isPending ? "Reverting…" : "Confirm Revert"}
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  setShowRevertForm(false)
                  setRevertReason("")
                }}
                disabled={revertMutation.isPending}
              >
                Cancel
              </Button>
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
