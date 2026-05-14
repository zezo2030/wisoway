// Wallet Detail Page: Wallet account details with transaction history

import { useParams, useNavigate, useSearchParams } from "react-router-dom"
import { useMemo, useState } from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { adjustWalletBalance, getWalletById, getWalletTransactions } from "@/api/wallets"
import { DataTable, type Column } from "@/components/data-table"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Separator } from "@/components/ui/separator"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { QUERY_KEYS, ROUTES } from "@/lib/constants"
import {
  formatDate,
  formatCurrency,
  formatPhone,
  formatRelativeTime,
  getWalletTransactionTypeLabel,
  cn,
} from "@/lib/utils"
import { WalletAccountType } from "@/types/enums"
import type { WalletTransaction, UserSummary } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import {
  ArrowLeft,
  Wallet,
  User,
  Mail,
  Phone,
  Calendar,
  ArrowUpCircle,
  ArrowDownCircle,
  AlertCircle,
  Plus,
  Minus,
  Hash,
} from "lucide-react"
import { toast } from "sonner"

function isPopulatedUser(userId: string | UserSummary): userId is UserSummary {
  return typeof userId === "object" && userId !== null && "name" in userId
}

export default function WalletDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { t, language } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const txPage = parseInt(searchParams.get("txPage") || "1", 10)
  const txLimit = 20
  const [adjustmentOpen, setAdjustmentOpen] = useState(false)
  const [adjustmentMode, setAdjustmentMode] = useState<"credit" | "debit">("credit")
  const [adjustmentAmount, setAdjustmentAmount] = useState("")
  const [adjustmentNote, setAdjustmentNote] = useState("")

  const { data: wallet, isLoading: walletLoading, error: walletError } = useQuery({
    queryKey: [QUERY_KEYS.WALLETS.DETAIL, id],
    queryFn: () => getWalletById(id!),
    enabled: !!id,
  })

  const { data: txData, isLoading: txLoading } = useQuery({
    queryKey: [QUERY_KEYS.WALLETS.TRANSACTIONS, id, { page: txPage, limit: txLimit }],
    queryFn: () => getWalletTransactions(id!, { page: txPage, limit: txLimit }),
    enabled: !!id,
  })

  const adjustmentValue = useMemo(() => {
    const parsed = Number(adjustmentAmount)
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return null
    }
    return adjustmentMode === "credit" ? parsed : -parsed
  }, [adjustmentAmount, adjustmentMode])

  const adjustMutation = useMutation({
    mutationFn: () =>
      adjustWalletBalance(id!, {
        amount: adjustmentValue!,
        currency: wallet?.currency,
        note: adjustmentNote.trim() || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.WALLETS.DETAIL, id] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.WALLETS.TRANSACTIONS, id] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.WALLETS.ALL] })
      toast.success(adjustmentMode === "credit" ? "Wallet credited successfully" : "Wallet debited successfully")
      setAdjustmentOpen(false)
      setAdjustmentAmount("")
      setAdjustmentNote("")
      setAdjustmentMode("credit")
    },
    onError: (error: Error) => {
      toast.error(error.message || "Failed to adjust wallet balance")
    },
  })

  const handleTxPageChange = (newPage: number) => {
    const newParams = new URLSearchParams(searchParams)
    newParams.set("txPage", String(newPage))
    setSearchParams(newParams)
  }

  const txColumns: Column<WalletTransaction>[] = [
    {
      key: "type",
      header: t("paymentType"),
      cell: (tx) => (
        <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-muted text-muted-foreground border border-border/40">
          {getWalletTransactionTypeLabel(tx.type)}
        </span>
      ),
    },
    {
      key: "direction",
      header: t("direction"),
      cell: (tx) => (
        <span
          className={cn(
            "inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full border",
            tx.direction === "credit"
              ? "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/30 dark:text-emerald-400 dark:border-emerald-800"
              : "bg-red-50 text-red-700 border-red-200 dark:bg-red-950/30 dark:text-red-400 dark:border-red-800"
          )}
        >
          {tx.direction === "credit" ? (
            <ArrowUpCircle className="w-3 h-3" />
          ) : (
            <ArrowDownCircle className="w-3 h-3" />
          )}
          {tx.direction === "credit" ? t("credit") : t("debit")}
        </span>
      ),
    },
    {
      key: "amount",
      header: t("amount"),
      cell: (tx) => (
        <div
          className={cn(
            "font-black",
            tx.direction === "credit"
              ? "text-emerald-600 dark:text-emerald-400"
              : "text-red-600 dark:text-red-400"
          )}
        >
          {tx.direction === "credit" ? "+" : "-"}
          {formatCurrency(tx.amount, tx.currency)}
        </div>
      ),
    },
    {
      key: "reference",
      header: t("reference"),
      cell: (tx) =>
        tx.referenceType && tx.referenceId ? (
          <div className="text-xs">
            <span className="font-medium text-foreground capitalize">
              {tx.referenceType}
            </span>
            <span className="text-muted-foreground font-mono ml-1.5">
              {tx.referenceId.slice(0, 8)}...
            </span>
          </div>
        ) : (
          <span className="text-muted-foreground">-</span>
        ),
    },
    {
      key: "status",
      header: t("status"),
      cell: (tx) => (
        <span
          className={cn(
            "text-xs font-semibold px-2.5 py-1 rounded-full border",
            tx.status === "posted"
              ? "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/30 dark:text-emerald-400 dark:border-emerald-800"
              : tx.status === "pending"
                ? "bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/30 dark:text-amber-400 dark:border-amber-800"
                : "bg-muted text-muted-foreground border-border/40"
          )}
        >
          {tx.status}
        </span>
      ),
    },
    {
      key: "date",
      header: t("date"),
      cell: (tx) => (
        <div>
          <div className="text-sm font-medium text-muted-foreground">
            {formatDate(tx.createdAt)}
          </div>
          <div className="text-xs text-muted-foreground/70">
            {formatRelativeTime(tx.createdAt)}
          </div>
        </div>
      ),
    },
  ]

  if (walletError) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <Button
          variant="ghost"
          onClick={() => navigate(ROUTES.WALLETS)}
          className="mb-2"
        >
          <ArrowLeft className={cn("w-4 h-4", language === "ar" ? "ml-2" : "mr-2")} />
          {t("backToWallets")}
        </Button>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">
            {t("noWalletsFound")}
          </span>
        </div>
      </div>
    )
  }

  const balance = wallet ? Number(wallet.balance) : 0
  const owner = wallet && isPopulatedUser(wallet.userId) ? wallet.userId : null

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <Button
        variant="ghost"
        onClick={() => navigate(ROUTES.WALLETS)}
        className="-ml-2 text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft className={cn("w-4 h-4", language === "ar" ? "ml-2" : "mr-2")} />
        {t("backToWallets")}
      </Button>

      {walletLoading ? (
        <div className="grid gap-6 lg:grid-cols-12">
          <Card className="lg:col-span-7 border-border/50 overflow-hidden animate-pulse">
            <div className="h-32 bg-muted/60" />
            <CardContent className="p-6 space-y-4">
              <div className="h-6 bg-muted rounded-lg w-2/3" />
              <div className="h-4 bg-muted rounded w-full" />
              <div className="h-4 bg-muted rounded w-5/6" />
            </CardContent>
          </Card>
          <div className="lg:col-span-5 flex flex-col gap-6">
            <Card className="h-56 border-border/50 animate-pulse bg-muted/30" />
            <Card className="h-36 border-border/50 animate-pulse bg-muted/30" />
          </div>
        </div>
      ) : wallet ? (
        <>
          <div className="flex flex-col gap-1 border-b border-border/40 pb-6">
            <h1 className="text-2xl md:text-3xl font-bold tracking-tight text-foreground">
              {t("walletDetail")}
            </h1>
            <p className="text-sm text-muted-foreground font-mono break-all">{wallet.id}</p>
          </div>

          <div className="grid gap-6 lg:grid-cols-12">
            <Card className="lg:col-span-7 border-border/50 shadow-lg bg-card/90 backdrop-blur-sm dark:shadow-none overflow-hidden">
              <CardHeader className="space-y-0 pb-4 bg-gradient-to-br from-primary/[0.06] via-muted/30 to-transparent border-b border-border/40">
                <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                  <div className="min-w-0 flex-1">
                    <p className="text-[11px] font-bold uppercase tracking-widest text-muted-foreground mb-2">
                      {t("walletAccountInfo")}
                    </p>
                    {owner ? (
                      <>
                        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide mb-1">
                          {t("walletOwner")}
                        </p>
                        <div className="flex items-center gap-4">
                          <div
                            className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-primary/15 text-primary text-xl font-black border border-primary/20 shadow-sm"
                            aria-hidden
                          >
                            {owner.name.charAt(0).toUpperCase()}
                          </div>
                          <p className="text-2xl md:text-3xl font-black text-foreground tracking-tight leading-tight break-words">
                            {owner.name}
                          </p>
                        </div>
                      </>
                    ) : (
                      <p className="text-sm text-muted-foreground font-mono">
                        {typeof wallet.userId === "string" ? `ID: ${wallet.userId}` : "—"}
                      </p>
                    )}
                  </div>
                  {owner && (
                    <Button
                      type="button"
                      variant="outline"
                      size="sm"
                      className="rounded-full shrink-0 border-border/80"
                      onClick={() => navigate(`${ROUTES.USERS}/${owner._id}`)}
                    >
                      <User className={cn("w-4 h-4", language === "ar" ? "ml-1.5" : "mr-1.5")} />
                      {t("viewUserProfile")}
                    </Button>
                  )}
                </div>
              </CardHeader>
              <CardContent className="p-6 space-y-6">
                {owner && (
                  <div className="space-y-3">
                    {owner.email ? (
                      <div className="flex items-start gap-3 text-sm">
                        <Mail className="w-4 h-4 mt-0.5 text-muted-foreground shrink-0" />
                        <span className="text-foreground break-all">{owner.email}</span>
                      </div>
                    ) : null}
                    {owner.phoneNumber ? (
                      <div className="flex items-start gap-3 text-sm">
                        <Phone className="w-4 h-4 mt-0.5 text-muted-foreground shrink-0" />
                        <span dir="ltr" className="text-foreground">
                          {formatPhone(owner.phoneNumber)}
                        </span>
                      </div>
                    ) : null}
                  </div>
                )}

                <Separator className="bg-border/60" />

                <div className="grid gap-5 sm:grid-cols-2">
                  <div className="rounded-xl border border-border/50 bg-muted/20 p-4">
                    <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-muted-foreground mb-2">
                      <Hash className="w-3.5 h-3.5" />
                      {t("walletInternalId")}
                    </div>
                    <p className="font-mono text-xs leading-relaxed break-all text-foreground/90">{wallet.id}</p>
                  </div>
                  <div className="rounded-xl border border-border/50 bg-muted/20 p-4">
                    <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-muted-foreground mb-2">
                      <Calendar className="w-3.5 h-3.5" />
                      {t("createdAt")}
                    </div>
                    <p className="text-sm font-semibold text-foreground">{formatDate(wallet.createdAt)}</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <div className="lg:col-span-5 flex flex-col gap-6">
              <Card className="border-border/50 shadow-lg bg-gradient-to-b from-emerald-500/[0.07] to-card dark:from-emerald-500/10 dark:to-card overflow-hidden">
                <CardHeader className="pb-2">
                  <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground flex items-center gap-2">
                    <Wallet className="w-4 h-4" />
                    {t("balance")}
                  </CardTitle>
                </CardHeader>
                <CardContent className="flex flex-col items-stretch pb-6">
                  <div
                    className={cn(
                      "text-4xl font-black tabular-nums text-center py-2",
                      balance > 0
                        ? "text-emerald-600 dark:text-emerald-400"
                        : "text-muted-foreground"
                    )}
                  >
                    {formatCurrency(balance, wallet.currency)}
                  </div>
                  <p className="text-center text-sm font-semibold text-muted-foreground">{wallet.currency}</p>
                  <div className="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-2">
                    <Button
                      className="rounded-xl"
                      onClick={() => {
                        setAdjustmentMode("credit")
                        setAdjustmentOpen(true)
                      }}
                    >
                      <Plus className={cn("w-4 h-4", language === "ar" ? "ml-1.5" : "mr-1.5")} />
                      Add Balance
                    </Button>
                    <Button
                      variant="outline"
                      className="rounded-xl border-border/80"
                      onClick={() => {
                        setAdjustmentMode("debit")
                        setAdjustmentOpen(true)
                      }}
                    >
                      <Minus className={cn("w-4 h-4", language === "ar" ? "ml-1.5" : "mr-1.5")} />
                      Deduct Balance
                    </Button>
                  </div>
                  <div className="mt-5 flex justify-center">
                    <Badge
                      variant="outline"
                      className={cn(
                        "text-xs font-semibold px-3 py-1.5 rounded-full",
                        wallet.accountType === WalletAccountType.DRIVER
                          ? "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/30 dark:text-blue-400 dark:border-blue-800"
                          : "bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-950/30 dark:text-purple-400 dark:border-purple-800"
                      )}
                    >
                      {wallet.accountType === WalletAccountType.DRIVER
                        ? t("nav_drivers")
                        : t("nav_passengers")}
                    </Badge>
                  </div>
                </CardContent>
              </Card>

              <Card className="border-border/50 shadow-md bg-card/80 backdrop-blur-sm dark:shadow-none">
                <CardHeader className="pb-2">
                  <CardTitle className="text-xs font-bold uppercase tracking-widest text-muted-foreground">
                    {t("status")}
                  </CardTitle>
                </CardHeader>
                <CardContent className="flex flex-col items-center justify-center pb-6 space-y-3">
                  <Badge
                    variant="outline"
                    className={cn(
                      "text-sm font-semibold px-4 py-2 rounded-full",
                      wallet.isActive
                        ? "bg-emerald-50 text-emerald-800 border-emerald-200 hover:bg-emerald-50 dark:bg-emerald-950/40 dark:text-emerald-300 dark:border-emerald-800"
                        : "bg-red-50 text-red-800 border-red-200 hover:bg-red-50 dark:bg-red-950/40 dark:text-red-300 dark:border-red-800"
                    )}
                  >
                    {wallet.isActive ? t("active") : t("inactive")}
                  </Badge>
                  <p className="text-xs text-muted-foreground text-center">
                    {t("lastUpdated")}: {formatDate(wallet.updatedAt)}
                  </p>
                </CardContent>
              </Card>
            </div>
          </div>

          {/* Transaction History */}
          <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
            <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
              <CardTitle className="text-lg font-bold flex items-center gap-2">
                {t("walletTransactions")}
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <div className="overflow-x-auto">
                <DataTable
                  columns={txColumns}
                  data={txData?.data || []}
                  page={txPage}
                  totalPages={txData?.meta.totalPages || 0}
                  total={txData?.meta.total || 0}
                  onPageChange={handleTxPageChange}
                  pageSize={txLimit}
                  loading={txLoading}
                  emptyMessage={t("noTransactionsFound")}
                />
              </div>
            </CardContent>
          </Card>
        </>
      ) : null}

      <Dialog open={adjustmentOpen} onOpenChange={setAdjustmentOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {adjustmentMode === "credit" ? "Add balance to wallet" : "Deduct balance from wallet"}
            </DialogTitle>
            <DialogDescription>
              This creates an `adjustment` transaction so the wallet history stays complete.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="grid gap-2">
              <label className="text-sm font-medium">Amount ({wallet?.currency ?? "JOD"})</label>
              <Input
                type="number"
                min="0.01"
                step="0.01"
                value={adjustmentAmount}
                onChange={(e) => setAdjustmentAmount(e.target.value)}
                placeholder="0.00"
              />
            </div>
            <div className="grid gap-2">
              <label className="text-sm font-medium">Note</label>
              <Textarea
                value={adjustmentNote}
                onChange={(e) => setAdjustmentNote(e.target.value)}
                placeholder="Reason for this manual adjustment"
                className="min-h-24"
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setAdjustmentOpen(false)}
              disabled={adjustMutation.isPending}
            >
              Cancel
            </Button>
            <Button
              onClick={() => adjustMutation.mutate()}
              disabled={!adjustmentValue || adjustMutation.isPending}
            >
              {adjustMutation.isPending
                ? "Saving..."
                : adjustmentMode === "credit"
                  ? "Confirm Add"
                  : "Confirm Deduct"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
