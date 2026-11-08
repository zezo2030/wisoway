import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { getPlatformSettings, patchPlatformSettings, type PlatformSettings } from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Loader2 } from "lucide-react"
import { useState } from "react"
import { PromotionsPanel } from "./promotions-panel"
import { useLanguage } from "@/providers/language-provider"
import type { TranslationKey } from "@/i18n/translations"

/** Same bounds the backend enforces. */
const PENALTY_MIN = 0
const PENALTY_MAX = 50

/** One rating-cut knob: its setting, and the copy that explains it. */
interface PenaltyKnob {
  key: keyof PlatformSettings
  title: TranslationKey
  description: TranslationKey
  label: TranslationKey
  example: TranslationKey
  off: TranslationKey
}

const KNOBS: PenaltyKnob[] = [
  {
    key: "lateRatingPenaltyPercent",
    title: "latePickupTitle",
    description: "latePickupDesc",
    label: "latePenaltyPercent",
    example: "latePenaltyExample",
    off: "latePenaltyOff",
  },
  {
    key: "cancelRatingPenaltyPercent",
    title: "cancelPenaltyTitle",
    description: "cancelPenaltyDesc",
    label: "cancelPenaltyPercent",
    example: "cancelPenaltyExample",
    off: "cancelPenaltyOff",
  },
]

export default function OperationsSettingsPage() {
  const { t } = useLanguage()
  const { data, isLoading } = useQuery({
    queryKey: ["admin", "platform-settings"],
    queryFn: getPlatformSettings,
  })

  if (isLoading || !data) {
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  return (
    <div className="space-y-6 p-6 max-w-3xl mx-auto">
      <PromotionsPanel />
      <div className="flex flex-col gap-2 mb-4">
        <h1 className="text-3xl font-bold tracking-tight">{t("operationsTitle")}</h1>
        <p className="text-muted-foreground text-base">{t("operationsSubtitle")}</p>
      </div>
      {KNOBS.map((knob) => (
        <PenaltyCard key={knob.key} knob={knob} saved={data[knob.key]} />
      ))}
      <CommissionCard setting="instantCommissionPercent" saved={data.instantCommissionPercent} />
      <CommissionCard setting="sharedCommissionPercent" saved={data.sharedCommissionPercent} />
      <MinimumTopupCard jod={data.minimumTopupJod} sar={data.minimumTopupSar} />
    </div>
  )
}

function CommissionCard({ setting, saved }: { setting: "instantCommissionPercent" | "sharedCommissionPercent"; saved: number }) {
  const { language } = useLanguage()
  const ar = language === "ar"
  const [draft, setDraft] = useState<string | null>(null)
  const value = draft ?? String(saved)
  const percent = Number(value)
  const qc = useQueryClient()
  const mutation = useMutation({
    mutationFn: () => patchPlatformSettings({ [setting]: percent }),
    onSuccess: () => { setDraft(null); qc.invalidateQueries({ queryKey: ["admin", "platform-settings"] }); toast.success(ar ? "تم الحفظ" : "Saved") },
    onError: (e: Error) => toast.error(e.message),
  })
  return <Card><CardHeader><CardTitle>{setting === "instantCommissionPercent"
    ? (ar ? "عمولة الرحلات المباشرة" : "Instant ride commission")
    : (ar ? "عمولة الرحلات المشتركة" : "Shared trip commission")}</CardTitle>
    <CardDescription>{ar ? "تُخصم عند انتهاء الرحلة من قيمة الحجوزات المكتملة وتُضاف لمحفظة التطبيق." : "Charged on completed fares at trip completion and credited to the platform wallet."}</CardDescription></CardHeader>
    <CardContent className="space-y-4"><Label htmlFor={setting}>{ar ? "النسبة المئوية" : "Percentage"}</Label>
      <Input id={setting} type="number" min={0} max={100} step={0.1} value={value} onChange={e => setDraft(e.target.value)} />
      <Button disabled={mutation.isPending || !value.trim() || !Number.isFinite(percent) || percent < 0 || percent > 100} onClick={() => mutation.mutate()}>{ar ? "حفظ" : "Save"}</Button>
    </CardContent></Card>
}

/** Same bounds as the server (PLATFORM_SETTINGS). */
const TOPUP_RANGE = { minimumTopupJod: [1, 500], minimumTopupSar: [5, 2500] } as const

function MinimumTopupCard({ jod, sar }: { jod: number; sar: number }) {
  const { language } = useLanguage()
  const ar = language === "ar"
  const qc = useQueryClient()
  const [draft, setDraft] = useState<{ jod?: string; sar?: string }>({})
  const jodValue = draft.jod ?? String(jod)
  const sarValue = draft.sar ?? String(sar)
  const inRange = (raw: string, [min, max]: readonly [number, number]) => {
    const n = Number(raw)
    return raw.trim() !== "" && Number.isFinite(n) && n >= min && n <= max
  }
  const valid =
    inRange(jodValue, TOPUP_RANGE.minimumTopupJod) && inRange(sarValue, TOPUP_RANGE.minimumTopupSar)
  const mutation = useMutation({
    mutationFn: () =>
      patchPlatformSettings({ minimumTopupJod: Number(jodValue), minimumTopupSar: Number(sarValue) }),
    onSuccess: () => {
      setDraft({})
      qc.invalidateQueries({ queryKey: ["admin", "platform-settings"] })
      toast.success(ar ? "تم الحفظ" : "Saved")
    },
    onError: (e: Error) => toast.error(e.message),
  })
  return (
    <Card>
      <CardHeader>
        <CardTitle>{ar ? "أقل مبلغ للشحن" : "Minimum top-up"}</CardTitle>
        <CardDescription>
          {ar
            ? "أقل مبلغ يُقبل في شحن المحفظة. هو نفسه الرصيد الترحيبي للسائق الجديد عند اعتماده، والرصيد الذي يجب أن يبقى في محفظة السائق بعد السحب، والشحن الذي يعيد السائق لاستقبال الرحلات بعد توقفه. العملات الأخرى تُحسب من مبلغ الدينار بسعر الصرف اليومي."
            : "The smallest wallet top-up accepted. It is also a newly approved driver's welcome credit, the balance a driver must keep after a withdrawal, and the top-up that lets a stopped driver take rides again. Other currencies use the JOD amount at the day's rate."}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="minimumTopupJod">{ar ? "بالدينار الأردني (JOD)" : "Jordanian dinar (JOD)"}</Label>
            <Input id="minimumTopupJod" type="number" min={1} max={500} step={0.5} value={jodValue}
              onChange={(e) => setDraft((d) => ({ ...d, jod: e.target.value }))} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="minimumTopupSar">{ar ? "بالريال السعودي (SAR)" : "Saudi riyal (SAR)"}</Label>
            <Input id="minimumTopupSar" type="number" min={5} max={2500} step={1} value={sarValue}
              onChange={(e) => setDraft((d) => ({ ...d, sar: e.target.value }))} />
          </div>
        </div>
        {!valid && (
          <p className="text-sm text-destructive">
            {ar ? "الدينار من 1 إلى 500، والريال من 5 إلى 2500." : "JOD 1–500, SAR 5–2500."}
          </p>
        )}
        <Button disabled={mutation.isPending || !valid} onClick={() => mutation.mutate()}>
          {ar ? "حفظ" : "Save"}
        </Button>
      </CardContent>
    </Card>
  )
}

function PenaltyCard({ knob, saved }: { knob: PenaltyKnob; saved: number }) {
  const qc = useQueryClient()
  const { t } = useLanguage()
  // What the admin is typing; until they touch the field, the saved value.
  const [draft, setDraft] = useState<string | null>(null)
  const value = draft ?? String(saved)
  const parsed = parseFloat(value)
  const valid = Number.isFinite(parsed) && parsed >= PENALTY_MIN && parsed <= PENALTY_MAX

  const mutation = useMutation({
    mutationFn: () => patchPlatformSettings({ [knob.key]: parsed }),
    onSuccess: () => {
      toast.success(t("saveSettings"))
      setDraft(null)
      qc.invalidateQueries({ queryKey: ["admin", "platform-settings"] })
    },
    onError: (e: unknown) => {
      const msg = e && typeof e === "object" && "message" in e ? String((e as Error).message) : "Save failed"
      toast.error(msg)
    },
  })

  // What a 4.8 rating drops to after one occurrence, to make the % concrete.
  const example = valid ? (4.8 * (1 - parsed / 100)).toFixed(2) : null
  const inputId = `penalty-${knob.key}`

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t(knob.title)}</CardTitle>
        <CardDescription>{t(knob.description)}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-3">
          <Label htmlFor={inputId}>{t(knob.label)}</Label>
          <Input
            id={inputId}
            type="number"
            min={PENALTY_MIN}
            max={PENALTY_MAX}
            step={0.5}
            value={value}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="2"
            className="max-w-[160px]"
          />
          {!valid && <p className="text-sm text-destructive">{t("latePenaltyRange")}</p>}
        </div>
        {valid && parsed === 0 && (
          <div className="bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-500 p-3 rounded-md text-sm font-medium border border-amber-200 dark:border-amber-900/50">
            {t(knob.off)}
          </div>
        )}
        {example && parsed > 0 && (
          <p className="text-sm text-muted-foreground">{t(knob.example).replace("{rating}", example)}</p>
        )}

        <div className="pt-4 flex justify-end border-t">
          <Button
            type="button"
            disabled={mutation.isPending || !valid}
            onClick={() => mutation.mutate()}
            className="min-w-[140px]"
          >
            {mutation.isPending ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin rtl:mr-0 rtl:ml-2" />
                {t("saving")}
              </>
            ) : (
              t("saveSettings")
            )}
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
