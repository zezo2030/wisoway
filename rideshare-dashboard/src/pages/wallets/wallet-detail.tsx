import { useState } from "react"
import { useNavigate, useParams } from "react-router-dom"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { adjustAdminWallet, getAdminWalletTransactions } from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { cn, formatCurrency, formatDateTime } from "@/lib/utils"
import type { WalletTransactionAdmin } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import { ArrowLeft, PlusCircle, MinusCircle, UserRound, AlertCircle } from "lucide-react"
import { toast } from "sonner"

type AdjustDirection = "credit" | "debit"

export default function WalletDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const { language } = useLanguage()

  const [direction, setDirection] = useState<AdjustDirection>("credit")
  const [amount, setAmount] = useState("")
  const [note, setNote] = useState("")
  const [referenceId, setReferenceId] = useState("")

  const walletTransactionsQuery = useQuery({
    queryKey: ["admin-wallet-transactions", id],
    queryFn: () => getAdminWalletTransactions(id!, 100),
    enabled: !!id,
  })

  const adjustMutation = useMutation({
    mutationFn: () =>
      adjustAdminWallet(id!, {
        direction,
        amount: Number(amount),
        note: note.trim() || undefined,
        referenceId: referenceId.trim() || undefined,
      }),
    onSuccess: () => {
      toast.success(language === "ar" ? "تم تعديل المحفظة بنجاح" : "Wallet adjusted successfully")
      setAmount("")
      setNote("")
      setReferenceId("")
      qc.invalidateQueries({ queryKey: ["admin-wallet-transactions", id] })
      qc.invalidateQueries({ queryKey: ["admin-wallets"] })
    },
    onError: (err: Error) => {
      toast.error(err.message || (language === "ar" ? "فشل تعديل المحفظة" : "Failed to adjust wallet"))
    },
  })

  const handleAdjust = () => {
    const parsed = Number(amount)
    if (!Number.isFinite(parsed) || parsed <= 0) {
      toast.error(language === "ar" ? "أدخل مبلغًا صحيحًا" : "Enter a valid amount")
      return
    }
    adjustMutation.mutate()
  }

  if (walletTransactionsQuery.error) {
    return (
      <div className="space-y-4">
        <Button variant="ghost" onClick={() => navigate(-1)} className="rounded-full">
          <ArrowLeft className={cn("h-4 w-4", language === "ar" ? "ml-2 rotate-180" : "mr-2")} />
          {language === "ar" ? "رجوع" : "Back"}
        </Button>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">
            {language === "ar" ? "فشل تحميل تفاصيل المحفظة" : "Failed to load wallet details"}
          </span>
        </div>
      </div>
    )
  }

  const payload = walletTransactionsQuery.data
  const account = payload?.account
  const txRows = payload?.transactions || []

  const getWalletTxTypeLabel = (type: string) => {
    const key = String(type || "").toLowerCase()
    const mapAr: Record<string, string> = {
      topup: "شحن محفظة",
      trip_debit: "خصم رحلة",
      trip_payment: "دفع رحلة",
      refund: "استرداد",
      payout: "سحب أرباح",
      adjustment: "تعديل إداري",
      hold: "حجز مبلغ",
      release_hold: "فك حجز",
    }
    const mapEn: Record<string, string> = {
      topup: "Wallet Top-up",
      trip_debit: "Trip Debit",
      trip_payment: "Trip Payment",
      refund: "Refund",
      payout: "Payout",
      adjustment: "Admin Adjustment",
      hold: "Hold",
      release_hold: "Release Hold",
    }
    if (language === "ar") return mapAr[key] || key.replaceAll("_", " ")
    return mapEn[key] || key.replaceAll("_", " ")
  }

  const getWalletDirectionLabel = (direction: string) => {
    const key = String(direction || "").toLowerCase()
    if (language === "ar") {
      if (key === "credit") return "إضافة"
      if (key === "debit") return "خصم"
      return key
    }
    if (key === "credit") return "Credit"
    if (key === "debit") return "Debit"
    return key
  }

  const getWalletStatusLabel = (status: string) => {
    const key = String(status || "").toLowerCase()
    if (language === "ar") {
      if (key === "posted") return "مُثبتة"
      if (key === "pending") return "قيد الانتظار"
      if (key === "failed") return "فشلت"
      if (key === "reversed") return "معكوسة"
      return key.replaceAll("_", " ")
    }
    if (key === "posted") return "Posted"
    if (key === "pending") return "Pending"
    if (key === "failed") return "Failed"
    if (key === "reversed") return "Reversed"
    return key.replaceAll("_", " ")
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-500 pb-10">
      <div className="flex items-center justify-between">
        <Button variant="ghost" onClick={() => navigate(-1)} className="rounded-full bg-muted/60 border border-border/50">
          <ArrowLeft className={cn("h-4 w-4", language === "ar" ? "ml-2 rotate-180" : "mr-2")} />
          {language === "ar" ? "العودة للمحافظ" : "Back to Wallets"}
        </Button>
      </div>

      {account ? (
        <div className="grid gap-6 grid-cols-1 xl:grid-cols-3">
          <Card className="xl:col-span-1 border-border/50 shadow-md">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg">
                <UserRound className="w-5 h-5 text-primary" />
                {language === "ar" ? "بيانات المحفظة" : "Wallet Profile"}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="text-sm text-muted-foreground">{account.user.name}</div>
              <div className="text-xs text-muted-foreground">{account.user.email || account.user.phoneNumber || "-"}</div>
              <div className="text-xs text-muted-foreground">ID: {account.id}</div>
              <div className="pt-2 text-3xl font-black text-emerald-600">
                {formatCurrency(Number(account.balance || 0), account.currency)}
              </div>
              <div className="text-xs text-muted-foreground">
                {account.accountType} / {account.user.role}
              </div>
            </CardContent>
          </Card>

          <Card className="xl:col-span-2 border-border/50 shadow-md">
            <CardHeader>
              <CardTitle>{language === "ar" ? "تعديل الرصيد" : "Balance Adjustment"}</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
                <Select value={direction} onValueChange={(v) => setDirection(v as AdjustDirection)}>
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="credit">
                      <span className="inline-flex items-center gap-1.5">
                        <PlusCircle className="w-4 h-4" />
                        {language === "ar" ? "إضافة" : "Credit"}
                      </span>
                    </SelectItem>
                    <SelectItem value="debit">
                      <span className="inline-flex items-center gap-1.5">
                        <MinusCircle className="w-4 h-4" />
                        {language === "ar" ? "خصم" : "Debit"}
                      </span>
                    </SelectItem>
                  </SelectContent>
                </Select>

                <Input
                  type="number"
                  min="0"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder={language === "ar" ? "المبلغ" : "Amount"}
                />

                <Input
                  value={referenceId}
                  onChange={(e) => setReferenceId(e.target.value)}
                  placeholder={language === "ar" ? "مرجع اختياري" : "Reference (optional)"}
                />

                <Button onClick={handleAdjust} disabled={adjustMutation.isPending}>
                  {adjustMutation.isPending
                    ? language === "ar"
                      ? "جاري التنفيذ..."
                      : "Processing..."
                    : language === "ar"
                      ? "تنفيذ"
                      : "Apply"}
                </Button>
              </div>

              <Textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder={language === "ar" ? "ملاحظة إدارية (اختياري)" : "Admin note (optional)"}
              />
            </CardContent>
          </Card>

          <Card className="xl:col-span-3 border-border/50 shadow-md">
            <CardHeader>
              <CardTitle>{language === "ar" ? "سجل العمليات" : "Transaction History"}</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-2 max-h-[420px] overflow-auto pr-1">
                {walletTransactionsQuery.isLoading ? (
                  <div className="text-sm text-muted-foreground">
                    {language === "ar" ? "جاري تحميل العمليات..." : "Loading transactions..."}
                  </div>
                ) : txRows.length === 0 ? (
                  <div className="text-sm text-muted-foreground">
                    {language === "ar" ? "لا توجد عمليات" : "No transactions"}
                  </div>
                ) : (
                    txRows.map((tx: WalletTransactionAdmin) => (
                      <div key={tx.id} className="rounded-lg border border-border/40 p-3 bg-background/50">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div className="text-sm font-semibold">
                            {getWalletTxTypeLabel(tx.type)} / {getWalletDirectionLabel(tx.direction)}
                          </div>
                        <div
                          className={cn(
                            "text-sm font-black",
                            tx.direction === "credit" ? "text-emerald-600" : "text-rose-600",
                          )}
                        >
                          {tx.direction === "credit" ? "+" : "-"}
                          {formatCurrency(Number(tx.amount || 0), tx.currency)}
                        </div>
                      </div>
                      <div className="mt-1 text-xs text-muted-foreground">
                        {formatDateTime(tx.createdAt)} - {getWalletStatusLabel(tx.status)}
                      </div>
                      {tx.referenceId ? (
                        <div className="mt-1 text-xs text-muted-foreground">
                          {language === "ar" ? "مرجع" : "Ref"}: {tx.referenceId}
                        </div>
                      ) : null}
                    </div>
                  ))
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      ) : null}
    </div>
  )
}
