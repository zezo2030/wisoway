import { useState } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { apiClient } from "@/api/client"
import { useLanguage } from "@/providers/language-provider"
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { toast } from "sonner"
interface Campaign { code: string; percent: string; tripType: string; startsAt: string; endsAt: string; active: boolean }
export function PromotionsPanel() {
  const { language } = useLanguage(); const ar = language === "ar"
  const qc = useQueryClient()
  const [code, setCode] = useState(""); const [percent,setPercent] = useState("10")
  const [tripType,setTripType] = useState("all"); const [startsAt,setStart] = useState(""); const [endsAt,setEnd] = useState(""); const [busy,setBusy] = useState(false)
  const list = useQuery({ queryKey:["promotions"], queryFn: async()=> (await apiClient.get<{data:Campaign[]}>("/promotions/admin")).data.data })
  async function create(e: React.FormEvent) {
    e.preventDefault(); setBusy(true)
    try { await apiClient.post("/promotions/admin",{code:code.trim().toUpperCase(),percent:Number(percent),tripType,startsAt:new Date(startsAt).toISOString(),endsAt:new Date(endsAt).toISOString(),active:true}); setCode(""); await qc.invalidateQueries({queryKey:["promotions"]}); toast.success(ar?"تم إنشاء الحملة":"Campaign created") }
    catch(e) { toast.error(e instanceof Error?e.message:"Error") } finally { setBusy(false) }
  }
  async function toggle(c:Campaign) {
    setBusy(true); try { await apiClient.patch(`/promotions/admin/${encodeURIComponent(c.code)}`,{active:!c.active}); await qc.invalidateQueries({queryKey:["promotions"]}) } catch(e) {toast.error(e instanceof Error?e.message:"Error")} finally {setBusy(false)}
  }
  return <Card><CardHeader><CardTitle>{ar?"أكواد خصم الركاب":"Passenger promotion codes"}</CardTitle></CardHeader><CardContent className="space-y-4">
    <p>{ar?"تتحمل المنصة الخصم بالكامل ولا تتأثر أرباح السائق. الأكواد متاحة لجميع الركاب دون حد لعدد الاستخدامات خلال مدة الحملة.":"The platform funds the full discount without reducing driver earnings. Codes allow unlimited uses by passengers during the campaign."}</p>
    <form onSubmit={create} className="grid gap-3 sm:grid-cols-2">
      <label>{ar?"الكود":"Code"}<Input required pattern="[A-Za-z0-9_-]{3,32}" value={code} onChange={e=>setCode(e.target.value)} /></label>
      <label>{ar?"نسبة الخصم %":"Discount %"}<Input required type="number" min="0.01" max="100" step="0.01" value={percent} onChange={e=>setPercent(e.target.value)} /></label>
      <label>{ar?"نوع الرحلة":"Ride type"}<select className="block border rounded p-2 w-full" value={tripType} onChange={e=>setTripType(e.target.value)}><option value="all">{ar?"الكل":"All"}</option><option value="instant">{ar?"مباشرة":"Instant"}</option><option value="shared">{ar?"مشتركة":"Shared"}</option></select></label>
      <label>{ar?"البداية":"Start"}<Input required type="datetime-local" value={startsAt} onChange={e=>setStart(e.target.value)} /></label>
      <label>{ar?"النهاية":"End"}<Input required type="datetime-local" value={endsAt} onChange={e=>setEnd(e.target.value)} /></label>
      <Button disabled={busy} type="submit">{ar?"إنشاء حملة":"Create campaign"}</Button>
    </form>
    {list.isError && <p role="alert">{ar?"تعذر تحميل الحملات":"Could not load campaigns"}</p>}
    {list.data?.map(c=><div key={c.code} className="flex justify-between gap-3 border rounded p-3"><span>{c.code} — {c.percent}% — {c.tripType}<br/>{new Date(c.startsAt).toLocaleString()} → {new Date(c.endsAt).toLocaleString()}</span><Button disabled={busy} variant="outline" onClick={()=>toggle(c)}>{c.active?(ar?"إيقاف":"Disable"):(ar?"تفعيل":"Enable")}</Button></div>)}
  </CardContent></Card>
}
