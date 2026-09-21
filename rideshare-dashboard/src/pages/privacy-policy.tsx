import { Link } from "react-router-dom"
import { Button } from "@/components/ui/button"
import { useLanguage } from "@/providers/language-provider"
import { cn } from "@/lib/utils"
import { Languages, ArrowLeft, Link2, Car } from "lucide-react"
import { toast } from "sonner"
import { PrivacyPolicyContent } from "@/legal/privacy-policy-content"
import { ROUTES } from "@/lib/constants"

const LAST_UPDATED = "2026-05-14"

export default function PrivacyPolicyPage() {
  const { t, language, setLanguage } = useLanguage()
  const isRtl = language === "ar"

  const copyPublicUrl = async () => {
    const url = window.location.href
    try {
      await navigator.clipboard.writeText(url)
      toast.success(t("privacyLinkCopied"))
    } catch {
      toast.error(t("privacyCopyFailed"))
    }
  }

  return (
    <div
      className="min-h-screen bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100"
      dir={isRtl ? "rtl" : "ltr"}
    >
      <header className="sticky top-0 z-10 border-b border-slate-200/80 bg-white/90 backdrop-blur-md dark:border-slate-800 dark:bg-slate-900/90">
        <div className="mx-auto flex h-14 max-w-3xl items-center justify-between gap-3 px-4 sm:px-6">
          <Link
            to={ROUTES.LOGIN}
            className="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-600 hover:text-slate-900 dark:text-slate-400 dark:hover:text-white"
          >
            <ArrowLeft className={cn("h-4 w-4", isRtl && "rotate-180")} />
            {t("privacyBackToLogin")}
          </Link>
          <div className="flex items-center gap-2">
            <Button type="button" variant="outline" size="sm" onClick={copyPublicUrl} className="h-8 gap-1.5 text-xs">
              <Link2 className="h-3.5 w-3.5" />
              {t("privacyCopyLink")}
            </Button>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              onClick={() => setLanguage(language === "en" ? "ar" : "en")}
              className="h-8 gap-1.5 text-xs font-semibold"
            >
              <Languages className="h-3.5 w-3.5" />
              {t("languageToggleLabel")}
            </Button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6 sm:py-14">
        <div className="mb-10 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex items-start gap-3">
            <div className="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-xl bg-primary text-primary-foreground shadow-md">
              <Car className="h-6 w-6" />
            </div>
            <div>
              <h1 className="text-2xl font-extrabold tracking-tight text-slate-900 dark:text-white sm:text-3xl">
                {t("privacyPageTitle")}
              </h1>
              <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{t("privacyPageSubtitle")}</p>
              <p className="mt-2 text-xs font-medium text-slate-400 dark:text-slate-500">
                {t("privacyLastUpdated")}: {LAST_UPDATED}
              </p>
            </div>
          </div>
        </div>

        <div className="rounded-2xl border border-slate-200/80 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900 sm:p-8">
          <PrivacyPolicyContent locale={language} />
        </div>

        <p className="mt-8 text-center text-xs text-slate-400 dark:text-slate-500">
          &copy; {new Date().getFullYear()} {t("rideshareAdmin")}. {t("allRightsReserved")}
        </p>
      </main>
    </div>
  )
}
