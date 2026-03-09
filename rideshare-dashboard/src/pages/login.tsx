import { useEffect } from "react"
import { useNavigate } from "react-router-dom"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import { z } from "zod"
import { useAuth } from "@/providers/auth-provider"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { AlertCircle, Loader2, Car, Map, ShieldCheck, Mail, Lock, ArrowRight } from "lucide-react"
import { Alert, AlertDescription } from "@/components/ui/alert"

const loginSchema = z.object({
  email: z.string().min(1, "Email is required").email("Please enter a valid email address"),
  password: z.string().min(1, "Password is required"),
})

type LoginFormData = z.infer<typeof loginSchema>

export default function LoginPage() {
  const navigate = useNavigate()
  const { login, isAuthenticated, isLoading, error, clearError } = useAuth()

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

  return (
    <div className="flex min-h-screen w-full bg-background font-sans selection:bg-primary selection:text-primary-foreground">
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
            <span className="text-2xl font-bold tracking-tight">Rideshare Admin</span>
          </div>

          <div className="max-w-lg space-y-6 text-white">
            <h1 className="text-4xl font-bold leading-tight md:text-5xl lg:leading-[1.1]">
              Manage the fleet, <br />
              <span className="text-white/70">optimize the routes.</span>
            </h1>
            <p className="max-w-md text-lg text-white/80">
              Access the central hub to monitor drivers, oversee passenger requests, and ensure safety across the entire platform.
            </p>

            <div className="grid grid-cols-2 gap-6 pt-8">
              <div className="flex items-center gap-3">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/10 backdrop-blur-sm">
                  <Map className="h-6 w-6 text-white/90" />
                </div>
                <div className="space-y-1">
                  <p className="text-sm font-medium leading-none text-white">Live Tracking</p>
                  <p className="text-xs text-white/60">Real-time map view</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-white/10 backdrop-blur-sm">
                  <ShieldCheck className="h-6 w-6 text-white/90" />
                </div>
                <div className="space-y-1">
                  <p className="text-sm font-medium leading-none text-white">Secure Platform</p>
                  <p className="text-xs text-white/60">Advanced protection</p>
                </div>
              </div>
            </div>
          </div>

          <div className="text-sm text-white/50">
            &copy; {new Date().getFullYear()} Rideshare Inc. All rights reserved.
          </div>
        </div>
      </div>

      {/* Right Pane - Form */}
      <div className="flex w-full items-center justify-center bg-slate-50 p-8 dark:bg-slate-950 lg:w-1/2 lg:p-12">
        <div className="mx-auto flex w-full max-w-[420px] flex-col justify-center rounded-3xl border border-slate-200/60 bg-white p-8 px-6 shadow-xl shadow-slate-200/50 backdrop-blur-xl sm:px-10 dark:border-slate-800/60 dark:bg-slate-900 dark:shadow-slate-900/50 block">

          <div className="mb-8 flex flex-col space-y-3 text-center lg:text-left">
            <div className="mb-4 flex items-center justify-center lg:hidden">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary shadow-md">
                <Car className="h-8 w-8 text-primary-foreground" />
              </div>
            </div>
            <h1 className="text-3xl font-extrabold tracking-tight text-slate-900 dark:text-white">Sign In</h1>
            <p className="text-sm font-medium text-slate-500 dark:text-slate-400">
              Enter your credentials to access the administrative dashboard
            </p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
            {error && (
              <Alert variant="destructive" className="animate-in fade-in slide-in-from-top-2 duration-300 border-2 rounded-xl">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription className="ml-1 font-semibold">{error}</AlertDescription>
              </Alert>
            )}

            <div className="space-y-5">
              <div className="group relative space-y-2">
                <Label htmlFor="email" className="text-sm font-bold text-slate-700 dark:text-slate-300">
                  Email Address
                </Label>
                <div className="relative flex items-center">
                  <Mail className="absolute left-4 h-5 w-5 text-slate-400 transition-colors group-focus-within:text-primary dark:text-slate-500" />
                  <Input
                    id="email"
                    type="email"
                    autoComplete="email"
                    placeholder="admin@example.com"
                    className="h-14 rounded-2xl border-slate-200 bg-slate-50/50 pl-12 text-base font-semibold text-slate-900 placeholder:text-slate-400 shadow-sm transition-all duration-300 focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/50 dark:text-white dark:placeholder:text-slate-500 dark:focus:bg-slate-950"
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
                    Password
                  </Label>
                  <a href="#" className="text-sm font-bold text-primary transition-colors hover:text-primary/80">
                    Forgot password?
                  </a>
                </div>
                <div className="relative flex items-center">
                  <Lock className="absolute left-4 h-5 w-5 text-slate-400 transition-colors group-focus-within:text-primary dark:text-slate-500" />
                  <Input
                    id="password"
                    type="password"
                    autoComplete="current-password"
                    placeholder="••••••••"
                    className="h-14 rounded-2xl border-slate-200 bg-slate-50/50 pl-12 text-base font-semibold text-slate-900 placeholder:text-slate-400 shadow-sm transition-all duration-300 focus:border-primary focus:bg-white focus:ring-4 focus:ring-primary/10 dark:border-slate-800 dark:bg-slate-950/50 dark:text-white dark:placeholder:text-slate-500 dark:focus:bg-slate-950"
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
                  <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                  Authenticating...
                </>
              ) : (
                <span className="flex items-center justify-center gap-2">
                  Sign In
                  <ArrowRight className="h-5 w-5 transition-transform group-hover:translate-x-1" />
                </span>
              )}
            </Button>
          </form>

        </div>
      </div>
    </div>
  )
}
