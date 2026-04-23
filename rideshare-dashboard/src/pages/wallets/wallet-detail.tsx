// Wallet Detail Page: Wallet account details with transaction history

import { useParams, useNavigate, useSearchParams } from "react-router-dom"
import { useMemo, useState } from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { adjustWalletBalance, getWalletById, getWalletTransactions } from "@/api/wallets"
import { DataTable, type Column } from "@/components/data-table"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
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
import { QUERY_KEYS } from "@/lib/constants"
import {
  formatDate,
  formatCurrency,
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
          onClick={() => navigate("/wallets")}
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

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <Button
        variant="ghost"
        onClick={() => navigate("/wallets")}
        className="mb-2"
      >
        <ArrowLeft className={cn("w-4 h-4", language === "ar" ? "ml-2" : "mr-2")} />
        {t("backToWallets")}
      </Button>

      {walletLoading ? (
        <div className="grid gap-6 md:grid-cols-3">
          {[1, 2, 3].map((i) => (
            <Card key={i} className="animate-pulse">
              <CardContent className="p-6">
                <div className="h-20 bg-muted rounded-lg" />
              </CardContent>
            </Card>
          ))}
        </div>
      ) : wallet ? (
        <>
          {/* Wallet Info Header */}
          <div className="grid gap-6 md:grid-cols-3">
            {/* User Info Card */}
            <Card className="border-border/50 shadow-md bg-card/80 backdrop-blur-sm dark:shadow-none md:col-span-1">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                  <User className="w-4 h-4" />
                  {t("walletAccountInfo")}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                {isPopulatedUser(wallet.userId) ? (
                  <>
                    <div className="flex items-center gap-3">
                      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-lg shadow-sm border border-primary/20">
                        {wallet.userId.name.charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <div className="font-bold text-foreground text-lg">
                          {wallet.userId.name}
                        </div>
                      </div>
                    </div>
                    {wallet.userId.email && (
                      <div className="flex items-center gap-2 text-sm text-muted-foreground">
                        <Mail className="w-4 h-4" />
                        {wallet.userId.email}
                      </div>
                    )}
                    {wallet.userId.phoneNumber && (
                      <div className="flex items-center gap-2 text-sm text-muted-foreground">
                        <Phone className="w-4 h-4" />
                        {wallet.userId.phoneNumber}
                      </div>
                    )}
                  </>
                ) : (
                  <span className="text-muted-foreground font-mono text-xs">
                    ID: {wallet.userId}
                  </span>
                )}
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <Calendar className="w-4 h-4" />
                  {t("createdAt")}: {formatDate(wallet.createdAt)}
                </div>
              </CardContent>
            </Card>

            {/* Balance Card */}
            <Card className="border-border/50 shadow-md bg-card/80 backdrop-blur-sm dark:shadow-none md:col-span-1">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                  <Wallet className="w-4 h-4" />
                  {t("balance")}
                </CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col items-center justify-center py-6">
                <div
                  className={cn(
                    "text-4xl font-black",
                    balance > 0
                      ? "text-emerald-600 dark:text-emerald-400"
                      : "text-muted-foreground"
                  )}
                >
                  {formatCurrency(balance, wallet.currency)}
                </div>
                <div className="text-sm text-muted-foreground mt-2 font-medium">
                  {wallet.currency}
                </div>
                <div className="mt-4 flex flex-wrap justify-center gap-2">
                  <Button
                    size="sm"
                    className="rounded-full"
                    onClick={() => {
                      setAdjustmentMode("credit")
                      setAdjustmentOpen(true)
                    }}
                  >
                    <Plus className="w-4 h-4 mr-1" />
                    Add Balance
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    className="rounded-full"
                    onClick={() => {
                      setAdjustmentMode("debit")
                      setAdjustmentOpen(true)
                    }}
                  >
                    <Minus className="w-4 h-4 mr-1" />
                    Deduct Balance
                  </Button>
                </div>
                <span
                  className={cn(
                    "mt-3 text-xs font-semibold px-3 py-1.5 rounded-full border",
                    wallet.accountType === WalletAccountType.DRIVER
                      ? "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/30 dark:text-blue-400 dark:border-blue-800"
                      : "bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-950/30 dark:text-purple-400 dark:border-purple-800"
                  )}
                >
                  {wallet.accountType === WalletAccountType.DRIVER
                    ? t("nav_drivers")
                    : t("nav_passengers")}
                </span>
              </CardContent>
            </Card>

            {/* Status Card */}
            <Card className="border-border/50 shadow-md bg-card/80 backdrop-blur-sm dark:shadow-none md:col-span-1">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">
                  {t("status")}
                </CardTitle>
              </CardHeader>
              <CardContent className="flex flex-col items-center justify-center py-6 space-y-3">
                <span
                  className={cn(
                    "text-sm font-semibold px-4 py-2 rounded-full border",
                    wallet.isActive
                      ? "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/30 dark:text-emerald-400 dark:border-emerald-800"
                      : "bg-red-50 text-red-700 border-red-200 dark:bg-red-950/30 dark:text-red-400 dark:border-red-800"
                  )}
                >
                  {wallet.isActive ? t("active") : t("inactive")}
                </span>
                <div className="text-xs text-muted-foreground">
                  {t("lastUpdated")}: {formatDate(wallet.updatedAt)}
                </div>
              </CardContent>
            </Card>
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
