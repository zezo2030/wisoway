import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import {
  getPlatformPricingSettings,
  patchPlatformPricingSettings,
} from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Loader2 } from "lucide-react"
import { useEffect, useState } from "react"
import { useLanguage } from "@/providers/language-provider"

/** Markets with a fee schedule; each trip is charged on its departure country's. */
const PRICING_COUNTRIES = ["JO", "SA", "AE", "QA", "KW", "BH", "OM", "EG", "IQ", "PS", "LB", "SY"] as const

function num(v: number | string | undefined): number {
  if (v === undefined || v === null) return 0
  if (typeof v === "number") return v
  const n = parseFloat(String(v))
  return Number.isFinite(n) ? n : 0
}

export default function PricingSettingsPage() {
  const qc = useQueryClient()
  const { t } = useLanguage()
  const [countryCode, setCountryCode] = useState<string>("JO")
  const { data, isLoading } = useQuery({
    queryKey: ["admin", "pricing-settings", countryCode],
    queryFn: () => getPlatformPricingSettings(countryCode),
  })

  const [feeAmount, setFeeAmount] = useState("")
  const [passengerPct, setPassengerPct] = useState("")
  const [driverUnlockPct, setDriverUnlockPct] = useState("")
  const [isActive, setIsActive] = useState(true)
  const [lifetimeFree, setLifetimeFree] = useState(true)

  useEffect(() => {
    if (!data) return
    setFeeAmount(String(num(data.feeAmount)))
    setPassengerPct(String(num(data.passengerPlatformPercent)))
    setDriverUnlockPct(String(num(data.driverUnlockPercent)))
    setIsActive(!!data.isActive)
    setLifetimeFree(data.lifetimeFreeTripEnabled !== false)
  }, [data])

  const mutation = useMutation({
    mutationFn: () =>
      patchPlatformPricingSettings(countryCode, {
        feeAmount: parseFloat(feeAmount) || 0,
        currency: data?.currency,
        isActive,
        passengerPlatformPercent: parseFloat(passengerPct) || 0,
        driverUnlockPercent: parseFloat(driverUnlockPct) || 0,
        lifetimeFreeTripEnabled: lifetimeFree,
      }),
    onSuccess: () => {
      toast.success(t("saveSettings"))
      qc.invalidateQueries({ queryKey: ["admin", "pricing-settings", countryCode] })
    },
    onError: (e: unknown) => {
      const msg = e && typeof e === "object" && "message" in e ? String((e as Error).message) : "Save failed"
      toast.error(msg)
    },
  })

  if (isLoading || !data) {
    return (
      <div className="flex justify-center p-12">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  return (
    <div className="space-y-6 p-6 max-w-5xl mx-auto">
      <div className="flex flex-col gap-2 mb-8">
        <h1 className="text-3xl font-bold tracking-tight">{t("pricingTitle")}</h1>
        <p className="text-muted-foreground text-base">
          {t("pricingSubtitle")} <span className="font-semibold text-foreground">{countryCode}</span>.
        </p>
        <div className="flex flex-wrap items-center gap-3 pt-2">
          <Label htmlFor="pricingCountry">{t("pricingCountry")}</Label>
          <Select value={countryCode} onValueChange={setCountryCode}>
            <SelectTrigger id="pricingCountry" className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PRICING_COUNTRIES.map((code) => (
                <SelectItem key={code} value={code}>
                  {code}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {!data.id && (
          <div className="bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-500 p-3 rounded-md text-sm font-medium border border-amber-200 dark:border-amber-900/50">
            {t("pricingFallbackNote")}
          </div>
        )}
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Passenger Card */}
        <Card>
          <CardHeader>
            <CardTitle>{t("passengerSettings")}</CardTitle>
            <CardDescription>{t("passengerSettingsDesc")}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-3">
              <Label htmlFor="passengerPct">{t("platformFeeOnSeat")}</Label>
              <Input
                id="passengerPct"
                type="number"
                min={0}
                max={100}
                step={0.01}
                value={passengerPct}
                onChange={(e) => setPassengerPct(e.target.value)}
                placeholder="0.00"
              />
            </div>
            {Number(passengerPct) === 0 && (
              <div className="bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-500 p-3 rounded-md text-sm font-medium border border-amber-200 dark:border-amber-900/50">
                {t("cashWarning")}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Driver Card */}
        <Card>
          <CardHeader>
            <CardTitle>{t("driverSettings")}</CardTitle>
            <CardDescription>{t("driverSettingsDesc")}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-5">
            <div className="space-y-3">
              <Label htmlFor="driverUnlockPct">{t("tripUnlockFee")}</Label>
              <Input
                id="driverUnlockPct"
                type="number"
                min={0}
                max={100}
                step={0.01}
                value={driverUnlockPct}
                onChange={(e) => setDriverUnlockPct(e.target.value)}
                placeholder="0.00"
              />
            </div>

            <div className="space-y-3 pt-2">
              <div>
                <Label htmlFor="legacyFee">{t("legacyFlatFee")}</Label>
                <p className="text-xs text-muted-foreground mt-1 mb-2">{t("legacyFlatFeeDesc")}</p>
              </div>
              <Input
                id="legacyFee"
                type="number"
                min={0}
                step={0.01}
                value={feeAmount}
                onChange={(e) => setFeeAmount(e.target.value)}
                placeholder="0.00"
              />
            </div>

            <div className="flex items-center gap-3 pt-4 border-t">
              <input
                id="lifetime"
                type="checkbox"
                className="h-4 w-4 rounded border-gray-300 text-primary shadow-sm focus:ring-primary"
                checked={lifetimeFree}
                onChange={(e) => setLifetimeFree(e.target.checked)}
              />
              <Label htmlFor="lifetime" className="font-medium cursor-pointer select-none">
                {t("firstTripFree")}
              </Label>
            </div>
          </CardContent>
        </Card>

        {/* General Card */}
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>{t("generalConfig")}</CardTitle>
            <CardDescription>{t("generalConfigDesc")}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="grid gap-6 md:grid-cols-2">
              <div className="space-y-3">
                <Label htmlFor="currency">{t("localCurrencyCode")}</Label>
                <Input id="currency" value={data.currency} readOnly disabled />
              </div>

              <div className="flex items-center gap-3 md:pt-8">
                <input
                  id="active"
                  type="checkbox"
                  className="h-4 w-4 rounded border-gray-300 text-primary shadow-sm focus:ring-primary"
                  checked={isActive}
                  onChange={(e) => setIsActive(e.target.checked)}
                />
                <Label htmlFor="active" className="font-medium cursor-pointer select-none">
                  {t("enablePricing")}
                </Label>
              </div>
            </div>

            <div className="pt-6 flex justify-end border-t mt-4">
              <Button
                type="button"
                disabled={mutation.isPending}
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
      </div>
    </div>
  )
}
