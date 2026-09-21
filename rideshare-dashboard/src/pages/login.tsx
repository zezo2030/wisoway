import { useEffect } from "react"
import { Link, useNavigate } from "react-router-dom"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useAuth } from "@/providers/auth-provider"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { AlertCircle, Loader2, Car, Map, ShieldCheck, Mail, Lock, ArrowRight, Languages } from "lucide-react"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useLanguage } from "@/providers/language-provider"
import { cn } from "@/lib/utils"
import { ROUTES } from "@/lib/constants"

export default function LoginPage() {
  const navigate = useNavigate()
  const { t, language, setLanguage } = useLanguage()
  const { login, isAuthenticated, isLoading, error, clearError } = useAuth()

  const loginSchema = z.object({
    email: z.string().min(1, t("emailRequired")).email(t("validEmail")),
    password: z.string().min(1, t("passwordRequired")),
  })

  type LoginFormData = z.infer<typeof loginSchema>

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  })

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      navigate("/dashboard", { replace: true })
    }
  }, [isAuthenticated, navigate])

  const onSubmit = async (data: LoginFormData) => {
    clearError()
    try {
      await login(data)
      navigate("/dashboard", { replace: true })
    } catch {
      // Error is handled by auth provider
    }
  }

  const toggleLanguage = () => {
    setLanguage(language === "en" ? "ar" : "en")
  }

  return (
    <div className="flex min-h-screen w-full bg-background font-sans selection:bg-primary selection:text-primary-foreground" dir={language === "ar" ? "rtl" : "ltr"}>
      {/* Language Switcher Overlay */}
      <div className={cn("absolute top-8 z-50", language === "ar" ? "left-8" : "right-8")}>
        <Button
          variant="ghost"
          size="sm"
          onClick={toggleLanguage}
          className="rounded-full bg-white/10 hover:bg-white/20 text-white dark:bg-slate-900/50 dark:hover:bg-slate-800/80 dark:text-slate-300 border border-white/10 dark:border-slate-800 backdrop-blur-md px-4 h-10 font-bold transition-all"
        >
          <Languages className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
          {t("languageToggleLabel")}
        </Button>
      </div>

      {/* Left Pane - Branding & Visuals */}
      <div className="relative hidden w-1/2 flex-col justify-between overflow-hidden bg-primary lg:flex">
        {/* Background Decorative Elements */}
        <div className="absolute -left-20 -top-20 h-[500px] w-[500px] rounded-full bg-white/10 blur-[100px]" />
        <div className="absolute -bottom-32 -right-32 h-[600px] w-[600px] rounded-full bg-black/20 blur-[120px]" />
        <div className="absolute left-1/2 top-1/2 h-[400px] w-[400px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/10" />

        <div className="relative z-10 flex h-full flex-col justify-between p-12">
          <div className="flex items-center gap-2 text-white">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white/20 backdrop-blur-md">
              <Car className="h-6 w-6 text-white" />
            </div>
            <span className="text-2xl font-bold tracking-tight">{t("rideshareAdmin")}</span>
          </div>

          <div className="max-w-lg space-y-6 text-white">
            <h1 className="text-4xl font-bold leading-tight md:text-5xl lg:leading-[1.1]">
              {t("manageFleet")} <br />
              <span className="text-white/70">{t("optimizeRoutes")}</span>
            </h1>
            <p className="max-w-md text-lg text-white/80">
              {t("centralHubAccess")}
            </p>

            <div className="grid grid-cols-2 gap-6 pt-8">
              <div className="flex items-center gap-3">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/10 backdrop-blur-sm">
                  <Map className="h-6 w-6 text-white/90" />
                </div>
                <div className="space-y-1 text-start">
                  <p className="text-sm font-medium leading-none text-white">{t("liveTracking")}</p>
                  <p className="text-xs text-white/60">{t("realTimeMap")}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/10 backdrop-blur-sm">
                  <ShieldCheck className="h-6 w-6 text-white/90" />
                </div>
                <div className="space-y-1 text-start">
                  <p className="text-sm font-medium leading-none text-white">{t("securePlatform")}</p>
                  <p className="text-xs text-white/60">{t("advancedProtection")}</p>
                </div>
              </div>
            </div>
          </div>

          <div className="text-sm text-white/50">
            &copy; {new Date().getFullYear()} {t("rideshareAdmin")}. {t("allRightsReserved")}
          </div>
        </div>
      </div>

      {/* Right Pane - Form */}
      <div className="flex w-full items-center justify-center bg-slate-50 p-8 dark:bg-slate-950 lg:w-1/2 lg:p-12">
        <div className="mx-auto flex w-full max-w-[420px] flex-col justify-center rounded-3xl border border-slate-200/60 bg-white p-8 px-6 shadow-xl shadow-slate-200/50 backdrop-blur-xl sm:px-10 dark:border-slate-800/60 dark:bg-slate-900 dark:shadow-slate-900/50">

          <div className="mb-8 flex flex-col space-y-3 text-center lg:text-start">
            <div className="mb-4 flex items-center justify-center lg:hidden">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary shadow-md">
                <Car className="h-8 w-8 text-primary-foreground" />
              </div>
            </div>
            <h1 className="text-3xl font-extrabold tracking-tight text-slate-900 dark:text-white">{t("signIn")}</h1>
            <p className="text-sm font-medium text-slate-500 dark:text-slate-400">
              {t("loginSubtitle")}
            </p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {error && (
              <Alert variant="destructive" className="animate-in fade-in slide-in-from-top-2 duration-300 border-2 rounded-xl">
                <AlertCircle className={cn("h-4 w-4", language === "ar" ? "ml-2" : "mr-2")} />
                <AlertDescription className="font-semibold">{error}</AlertDescription>
              </Alert>
            )}

            <div className="space-y-5">
              <div className="group relative space-y-2">
                <Label htmlFor="email" className="text-sm font-bold text-slate-700 dark:text-slate-300">
                  {t("emailLabel")}
                </Label>
                <div className="relative flex items-center">
                  <Mail className={cn("absolute h-5 w-5 text-slate-400 transition-colors group-focus-within:text-primary dark:text-slate-500", language === "ar" ? "right-4" : "left-4")} />
                  <Input
                    id="email"
                    type="email"
                    autoComplete="email"
                    placeholder={t("emailPlaceholder")}
                    className={cn(
                      "h-14 rounded-2xl border-slate-200 bg-slate-50/50 text-base font-semibold text-slate-900 placeholder:text-slate-400 shadow-sm transition-all duration-300 focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/50 dark:text-white dark:placeholder:text-slate-500 dark:focus:bg-slate-950",
                      language === "ar" ? "pr-12" : "pl-12"
                    )}
                    {...register("email")}
                    disabled={isLoading || isSubmitting}
                  />
                </div>
                {errors.email && (
                  <p className="animate-in fade-in text-xs font-bold text-destructive">
                    {errors.email.message}
                  </p>
                )}
              </div>

              <div className="group relative space-y-2">
                <div className="flex items-center justify-between">
                  <Label htmlFor="password" className="text-sm font-bold text-slate-700 dark:text-slate-300">
                    {t("passwordLabel")}
                  </Label>
                  <a href="#" className="text-sm font-bold text-primary transition-colors hover:text-primary/80">
                    {t("forgotPassword")}
                  </a>
                </div>
                <div className="relative flex items-center">
                  <Lock className={cn("absolute h-5 w-5 text-slate-400 transition-colors group-focus-within:text-primary dark:text-slate-500", language === "ar" ? "right-4" : "left-4")} />
                  <Input
                    id="password"
                    type="password"
                    autoComplete="current-password"
                    placeholder={t("passwordPlaceholder")}
                    className={cn(
                      "h-14 rounded-2xl border-slate-200 bg-slate-50/50 text-base font-semibold text-slate-900 placeholder:text-slate-400 shadow-sm transition-all duration-300 focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/50 dark:text-white dark:placeholder:text-slate-500 dark:focus:bg-slate-950",
                      language === "ar" ? "pr-12" : "pl-12"
                    )}
                    {...register("password")}
                    disabled={isLoading || isSubmitting}
                  />
                </div>
                {errors.password && (
                  <p className="animate-in fade-in text-xs font-bold text-destructive">
                    {errors.password.message}
                  </p>
                )}
              </div>
            </div>

            <Button
              type="submit"
              className="group h-14 w-full rounded-2xl text-base font-bold shadow-md transition-all duration-300 hover:-translate-y-0.5 hover:shadow-xl hover:shadow-primary/30 disabled:pointer-events-none disabled:opacity-70 mt-2"
              disabled={isLoading || isSubmitting}
            >
              {isLoading || isSubmitting ? (
                <>
                  <Loader2 className={cn("h-5 w-5 animate-spin", language === "ar" ? "ml-2" : "mr-2")} />
                  {t("authenticating")}
                </>
              ) : (
                <span className="flex items-center justify-center gap-2">
                  {t("signIn")}
                  <ArrowRight className={cn("h-5 w-5 transition-transform", language === "ar" ? "rotate-180 group-hover:-translate-x-1" : "group-hover:translate-x-1")} />
                </span>
              )}
            </Button>
          </form>

          <p className="mt-6 text-center text-xs text-slate-500 dark:text-slate-400">
            <Link
              to={ROUTES.PRIVACY}
              className="font-semibold text-primary underline-offset-4 hover:underline"
            >
              {t("privacyLoginFooter")}
            </Link>
          </p>

        </div>
      </div>
    </div>
  )
}
