import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { Loader2 } from "lucide-react"
import { useState } from "react"
import {
  getFareTariffs,
  patchFareTariff,
  resetFareTariff,
  type FareTariff,
  type FareTariffPatch,
} from "@/api/admin"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useLanguage } from "@/providers/language-provider"
import type { TranslationKey } from "@/i18n/translations"

type Field = keyof FareTariffPatch

/** The tariff's knobs, in the order a meter reads them. */
const FIELDS: { key: Field; label: TranslationKey; hint: TranslationKey; step: number }[] = [
  { key: "base", label: "fareBase", hint: "fareBaseHint", step: 0.01 },
  { key: "perKm", label: "farePerKm", hint: "farePerKmHint", step: 0.001 },
  { key: "perMin", label: "farePerMin", hint: "farePerMinHint", step: 0.001 },
  { key: "waitPerMin", label: "fareWaitPerMin", hint: "fareWaitPerMinHint", step: 0.001 },
  { key: "freeWaitMin", label: "fareFreeWait", hint: "fareFreeWaitHint", step: 1 },
  { key: "minimum", label: "fareMinimum", hint: "fareMinimumHint", step: 0.01 },
  { key: "step", label: "fareStep", hint: "fareStepHint", step: 0.01 },
]

/** The server's formula (instant-rides.constants computeFare / waitingCharge). */
function priceOf(t: Record<Field, number>, km: number, min: number, waitMin: number): number {
  const raw = Math.max(t.minimum, t.base + km * t.perKm + min * t.perMin)
  const fare = t.step > 0 ? Math.ceil(raw / t.step - 1e-9) * t.step : raw
  const waiting = Math.max(0, waitMin - t.freeWaitMin) * t.waitPerMin
  return Math.round((fare + waiting) * 100) / 100
}

export function InstantFarePanel() {
  const { t } = useLanguage()
  const { data, isLoading } = useQuery({
    queryKey: ["admin", "instant-fare-tariffs"],
    queryFn: getFareTariffs,
  })
  const [currency, setCurrency] = useState("JOD")
  const tariff = data?.find((row) => row.currency === currency) ?? data?.[0]

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t("instantFareTitle")}</CardTitle>
        <CardDescription>{t("instantFareDesc")}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {isLoading || !data || !tariff ? (
          <div className="flex justify-center p-6">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <>
            <div className="flex flex-wrap items-center gap-3">
              <Label htmlFor="fareCurrency">{t("instantFareCurrency")}</Label>
              <Select value={tariff.currency} onValueChange={setCurrency}>
                <SelectTrigger id="fareCurrency" className="w-32">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {data.map((row) => (
                    <SelectItem key={row.currency} value={row.currency}>
                      {row.currency}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Badge variant={tariff.customized ? "default" : "secondary"}>
                {t(tariff.customized ? "fareCustomBadge" : "fareDefaultBadge")}
              </Badge>
            </div>
            {/* Keyed by currency: switching starts a fresh form. */}
            <TariffForm key={`${tariff.currency}-${tariff.customized}`} tariff={tariff} />
          </>
        )}
      </CardContent>
    </Card>
  )
}

function TariffForm({ tariff }: { tariff: FareTariff }) {
  const { t } = useLanguage()
  const qc = useQueryClient()
  const [draft, setDraft] = useState<Record<Field, string>>(
    () => Object.fromEntries(FIELDS.map((f) => [f.key, String(tariff[f.key])])) as Record<Field, string>,
  )
  const values = Object.fromEntries(FIELDS.map((f) => [f.key, parseFloat(draft[f.key])])) as Record<Field, number>
  const valid = FIELDS.every((f) => Number.isFinite(values[f.key]) && values[f.key] >= 0) && values.step > 0

  const refresh = () => qc.invalidateQueries({ queryKey: ["admin", "instant-fare-tariffs"] })
  const onError = (e: unknown) => toast.error(e instanceof Error ? e.message : "Save failed")
  const save = useMutation({
    mutationFn: () => patchFareTariff(tariff.currency, values),
    onSuccess: () => {
      toast.success(t("saveSettings"))
      refresh()
    },
    onError,
  })
  const reset = useMutation({
    mutationFn: () => resetFareTariff(tariff.currency),
    onSuccess: () => {
      toast.success(t("fareReset"))
      refresh()
    },
    onError,
  })

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2">
        {FIELDS.map((f) => (
          <div key={f.key} className="space-y-1.5">
            <Label htmlFor={`fare-${f.key}`}>
              {t(f.label)}
              {f.key !== "freeWaitMin" && <span className="text-muted-foreground"> ({tariff.currency})</span>}
            </Label>
            <Input
              id={`fare-${f.key}`}
              type="number"
              min={0}
              step={f.step}
              value={draft[f.key]}
              onChange={(e) => setDraft((d) => ({ ...d, [f.key]: e.target.value }))}
            />
            <p className="text-xs text-muted-foreground">{t(f.hint)}</p>
          </div>
        ))}
      </div>

      {valid ? (
        <div className="rounded-md border bg-muted/40 p-3 text-sm">
          {t("fareExample")
            .replace("{price}", priceOf(values, 10, 15, 0).toFixed(2))
            .replace("{waitPrice}", priceOf(values, 10, 15, 5).toFixed(2))
            .split("{currency}")
            .join(tariff.currency)}
        </div>
      ) : (
        <p className="text-sm text-destructive">{t("fareInvalid")}</p>
      )}

      <div className="flex flex-wrap justify-end gap-3 border-t pt-4">
        {tariff.customized && (
          <Button type="button" variant="outline" disabled={reset.isPending} onClick={() => reset.mutate()}>
            {t("fareResetAction")}
          </Button>
        )}
        <Button type="button" disabled={!valid || save.isPending} onClick={() => save.mutate()} className="min-w-[140px]">
          {save.isPending ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin rtl:mr-0 rtl:ml-2" />
              {t("saving")}
            </>
          ) : (
            t("saveSettings")
          )}
        </Button>
      </div>
    </div>
  )
}
