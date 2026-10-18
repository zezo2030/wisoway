import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { getPlatformSettings, patchPlatformSettings, type PlatformSettings } from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Loader2 } from "lucide-react"
import { useState } from "react"
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
      <div className="flex flex-col gap-2 mb-4">
        <h1 className="text-3xl font-bold tracking-tight">{t("operationsTitle")}</h1>
        <p className="text-muted-foreground text-base">{t("operationsSubtitle")}</p>
      </div>
      {KNOBS.map((knob) => (
        <PenaltyCard key={knob.key} knob={knob} saved={data[knob.key]} />
      ))}
    </div>
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
