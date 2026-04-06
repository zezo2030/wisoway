import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { StatusBadge } from "@/components/status-badge"
import { ImagePreview } from "@/components/image-preview"
import { formatCurrency, formatDateTime, getPaymentTypeLabel, getTripLocationName } from "@/lib/utils"
import type { Payment, TripSummary, UserSummary, BookingSummary } from "@/types/models"
import { ArrowLeftRight } from "lucide-react"

interface PaymentDetailsDialogProps {
  payment: Payment | null
  open: boolean
  onOpenChange: (open: boolean) => void
  title?: string
}

function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

function isPopulatedTrip(tripId: string | TripSummary | undefined): tripId is TripSummary {
  return typeof tripId === "object" && tripId !== null && "from" in tripId
}

function isPopulatedBooking(bookingId: string | BookingSummary | undefined): bookingId is BookingSummary {
  return typeof bookingId === "object" && bookingId !== null && "seatNumber" in bookingId
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-12 gap-3 border-b border-border/40 py-2.5">
      <div className="col-span-4 text-xs font-semibold text-muted-foreground uppercase tracking-wide">{label}</div>
      <div className="col-span-8 text-sm font-medium text-foreground break-all">{value || "-"}</div>
    </div>
  )
}

export function PaymentDetailsDialog({
  payment,
  open,
  onOpenChange,
  title = "Payment Invoice Details",
}: PaymentDetailsDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-2xl max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>

        {!payment ? null : (
          <div className="space-y-4">
            <div className="rounded-xl border border-border/50 bg-muted/20 p-4">
              <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Amount</div>
              <div className="mt-1 text-2xl font-black text-emerald-600">
                {formatCurrency(payment.amount, payment.currency)}
              </div>
              <div className="mt-2 flex flex-wrap gap-2">
                <StatusBadge status={payment.status} type="payment" />
                <StatusBadge status={payment.method} type="payment" />
              </div>
            </div>

            <div className="rounded-xl border border-border/50 bg-background p-3">
              <DetailRow label="Payment ID" value={payment._id} />
              <DetailRow label="Type" value={getPaymentTypeLabel(payment.paymentType)} />
              <DetailRow label="Currency" value={payment.currency} />
              <DetailRow label="Created At" value={formatDateTime(payment.createdAt)} />
              <DetailRow label="Updated At" value={formatDateTime(payment.updatedAt)} />
              <DetailRow label="Wallet Number" value={payment.walletNumber || "-"} />
              <DetailRow label="Transaction ID" value={payment.transactionId || "-"} />
              <DetailRow label="Gateway Ref" value={payment.paymentGatewayRef || "-"} />
              <DetailRow label="Admin Note" value={payment.adminNote || "-"} />
            </div>

            <div className="rounded-xl border border-border/50 bg-background p-3">
              <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">User</div>
              <div className="mt-2 text-sm">
                {isPopulatedUser(payment.userId) ? (
                  <>
                    <div className="font-semibold">{payment.userId.name}</div>
                    <div className="text-muted-foreground">{payment.userId.email}</div>
                    <div className="text-xs text-muted-foreground mt-1">ID: {payment.userId._id}</div>
                  </>
                ) : (
                  <div className="text-muted-foreground">ID: {payment.userId}</div>
                )}
              </div>
            </div>

            <div className="rounded-xl border border-border/50 bg-background p-3">
              <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Trip</div>
              <div className="mt-2 text-sm">
                {isPopulatedTrip(payment.tripId) ? (
                  <>
                    <div className="font-semibold flex items-center gap-1.5">
                      {getTripLocationName(payment.tripId as unknown as Record<string, unknown>, "from")}
                      <ArrowLeftRight className="w-3.5 h-3.5 text-muted-foreground" />
                      {getTripLocationName(payment.tripId as unknown as Record<string, unknown>, "to")}
                    </div>
                    <div className="text-muted-foreground mt-1">
                      Departure: {formatDateTime(payment.tripId.departureTime)}
                    </div>
                    <div className="text-xs text-muted-foreground mt-1">ID: {payment.tripId._id}</div>
                  </>
                ) : payment.tripId ? (
                  <div className="text-muted-foreground">ID: {payment.tripId}</div>
                ) : (
                  <div className="text-muted-foreground">No trip linked</div>
                )}
              </div>
            </div>

            <div className="rounded-xl border border-border/50 bg-background p-3">
              <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">Booking</div>
              <div className="mt-2 text-sm">
                {isPopulatedBooking(payment.bookingId) ? (
                  <>
                    <div className="font-semibold">Seat: {payment.bookingId.seatNumber}</div>
                    <div className="text-xs text-muted-foreground mt-1">ID: {payment.bookingId._id}</div>
                  </>
                ) : payment.bookingId ? (
                  <div className="text-muted-foreground">ID: {payment.bookingId}</div>
                ) : (
                  <div className="text-muted-foreground">No booking linked</div>
                )}
              </div>
            </div>

            <div className="rounded-xl border border-border/50 bg-background p-3">
              <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-2">Invoice / Proof</div>
              <ImagePreview
                imageUrl={payment.proofImageUrl}
                alt="Payment proof image"
                thumbnailClassName="h-24 w-24 rounded-lg border border-border/50 object-cover"
              />
            </div>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}

