// DeleteUserDialog: shows what a permanent delete removes before it happens.
// Typing the phone number guards an action nothing can undo.

import { useState } from "react"
import { useMutation, useQuery } from "@tanstack/react-query"
import { toast } from "sonner"

import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { deleteUser, getUserDeletionPreview } from "@/api/admin"
import type { UserDeletionBlocker } from "@/api/admin"
import type { TranslationKey } from "@/i18n/translations"
import { QUERY_KEYS } from "@/lib/constants"
import { useLanguage } from "@/providers/language-provider"

const BLOCKER_TEXT: Record<UserDeletionBlocker, TranslationKey> = {
  ACTIVE_TRIP: "deleteBlockedActiveTrip",
  ACTIVE_BOOKING: "deleteBlockedActiveBooking",
  INSTANT_SEARCH: "deleteBlockedInstantSearch",
  WALLET_NOT_EMPTY: "deleteBlockedWallet",
  OPEN_PAYOUT: "deleteBlockedPayout",
  RECENT_PAYMENT: "deleteBlockedPayment",
}

export interface DeleteUserTarget {
  id: string
  name: string
  phoneNumber?: string
}

interface DeleteUserDialogProps {
  target: DeleteUserTarget | null
  onClose: () => void
  onDeleted: () => void
}

export function DeleteUserDialog({ target, onClose, onDeleted }: DeleteUserDialogProps) {
  return (
    <AlertDialog open={target !== null} onOpenChange={(open) => !open && onClose()}>
      {target && (
        <DeleteUserContent
          key={target.id}
          target={target}
          onClose={onClose}
          onDeleted={onDeleted}
        />
      )}
    </AlertDialog>
  )
}

function DeleteUserContent({
  target,
  onClose,
  onDeleted,
}: {
  target: DeleteUserTarget
  onClose: () => void
  onDeleted: () => void
}) {
  const { t } = useLanguage()
  const [typed, setTyped] = useState("")
  const expected = target.phoneNumber || target.name

  const preview = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.USER, target.id, "deletion-preview"],
    queryFn: () => getUserDeletionPreview(target.id),
    gcTime: 0,
  })

  const remove = useMutation({
    mutationFn: () => deleteUser(target.id),
    onSuccess: () => {
      toast.success(t("userDeleted"))
      onDeleted()
    },
    onError: () => {
      toast.error(t("failedToDeleteUser"))
      // Something may have started since the dialog opened.
      void preview.refetch()
    },
  })

  const counts = preview.data?.counts
  const blockers = preview.data?.blockers ?? []
  const canDelete =
    preview.isSuccess && blockers.length === 0 && typed.trim() === expected

  return (
    <AlertDialogContent>
      <AlertDialogHeader>
        <AlertDialogTitle>{t("deleteConfirmTitle")}</AlertDialogTitle>
        <AlertDialogDescription>
          {target.name} — {t("deleteConfirmDesc")}
        </AlertDialogDescription>
      </AlertDialogHeader>

      {preview.isLoading && <p className="text-sm">{t("loading")}</p>}
      {preview.isError && (
        <p className="text-sm text-destructive">{t("deletePreviewFailed")}</p>
      )}

      {blockers.length > 0 && (
        <div className="space-y-2 text-sm">
          <p className="font-medium text-destructive">{t("deleteBlockedTitle")}</p>
          <ul className="list-disc space-y-1 ps-5">
            {blockers.map((blocker) => (
              <li key={blocker}>{t(BLOCKER_TEXT[blocker])}</li>
            ))}
          </ul>
        </div>
      )}

      {counts && blockers.length === 0 && (
        <div className="space-y-3 text-sm">
          <p className="font-medium">{t("deleteWillRemove")}</p>
          <ul className="list-disc space-y-1 ps-5">
            <li>{t("deleteCountTrips")}: {counts.trips}</li>
            {counts.otherPassengersBookings > 0 && (
              <li className="text-destructive">
                {t("deleteCountOtherBookings")}: {counts.otherPassengersBookings}
              </li>
            )}
            <li>{t("deleteCountBookings")}: {counts.bookings}</li>
            <li>{t("deleteCountPayments")}: {counts.payments}</li>
            <li>{t("deleteCountMessages")}: {counts.messages}</li>
            <li>{t("deleteCountRatings")}: {counts.ratings}</li>
          </ul>
          <div className="space-y-1">
            <p>
              {t("deleteTypeToConfirm")}{" "}
              <span dir="ltr" className="font-mono font-medium">{expected}</span>
            </p>
            <Input
              dir="ltr"
              value={typed}
              onChange={(event) => setTyped(event.target.value)}
              autoComplete="off"
            />
          </div>
        </div>
      )}

      <AlertDialogFooter>
        <AlertDialogCancel disabled={remove.isPending} onClick={onClose}>
          {t("cancel")}
        </AlertDialogCancel>
        <Button
          variant="destructive"
          disabled={!canDelete || remove.isPending}
          onClick={() => remove.mutate()}
        >
          {t("deleteUser")}
        </Button>
      </AlertDialogFooter>
    </AlertDialogContent>
  )
}
