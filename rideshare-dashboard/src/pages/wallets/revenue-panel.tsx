import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { apiClient } from "@/api/client"
import { useLanguage } from "@/providers/language-provider"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { toast } from "sonner"

interface Payout { id: string; driverId: string; amount: string; currency: string; status: string; bankAccountRef: string; createdAt: string }
interface Balance { id: string; balance: string; currency: string }
export function RevenuePanel() {
  const { language } = useLanguage()
  const ar = language === "ar"
  const qc = useQueryClient()
  const balances = useQuery({ queryKey: ["platform-balances"], queryFn: async () => (await apiClient.get<{ data: Balance[] }>("/wallet/admin/platform-balances")).data.data })
  const payouts = useQuery({ queryKey: ["payouts"], queryFn: async () => (await apiClient.get<{ data: Payout[] }>("/wallet/admin/payout-requests")).data.data })
  const update = useMutation({ mutationFn: async ({ id, status }: { id: string; status: string }) => apiClient.patch(`/wallet/admin/payout-requests/${id}`, { status }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["payouts"] }); qc.invalidateQueries({ queryKey: ["wallets"] }); toast.success(ar ? "تم تحديث الطلب" : "Request updated") },
    onError: (e: Error) => toast.error(e.message) })
  return <Card><CardHeader><CardTitle>{ar ? "محفظة التطبيق وطلبات سحب الأرباح" : "Platform wallet and earnings withdrawals"}</CardTitle></CardHeader><CardContent className="space-y-4">
    {(balances.error || payouts.error) && <p role="alert">{ar ? "تعذر تحميل بيانات المحفظة" : "Could not load wallet data"}</p>}
    <div className="flex gap-4 flex-wrap">{balances.data?.map(b => <strong key={b.id}>{b.balance} {b.currency}</strong>)}</div>
    <p>{ar ? "حوّل المبلغ إلى حساب السائق عبر CliQ، ثم أكّد التحويل. المبلغ محجوز حتى تأكيد التحويل أو رفض الطلب." : "Transfer the money to the driver's CliQ account, then confirm payment. Funds remain reserved until paid or rejected."}</p>
    <div className="overflow-x-auto"><table className="w-full text-sm"><thead><tr>{(ar ? ["السائق", "المبلغ", "حساب CliQ", "الحالة", "الإجراء"] : ["Driver", "Amount", "CliQ account", "Status", "Action"]).map(x => <th className="p-2 text-start" key={x}>{x}</th>)}</tr></thead><tbody>
      {payouts.data?.map(p => <tr key={p.id}><td className="p-2">{p.driverId}</td><td>{p.amount} {p.currency}</td><td>{p.bankAccountRef}</td><td>{p.status}</td><td className="flex gap-2 p-2">
        {["pending", "approved"].includes(p.status) && <><Button disabled={update.isPending} onClick={() => { if (window.confirm(ar ? "هل حوّلت المبلغ بالفعل إلى حساب السائق؟" : "Have you already transferred the money to the driver?")) update.mutate({ id: p.id, status: "paid" }) }}>{ar ? "تم التحويل" : "Mark paid"}</Button>
        <Button variant="outline" disabled={update.isPending} onClick={() => update.mutate({ id: p.id, status: "rejected" })}>{ar ? "رفض" : "Reject"}</Button></>}
      </td></tr>)}
    </tbody></table></div>
  </CardContent></Card>
}
