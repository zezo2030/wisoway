import { useQuery, useQueryClient } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import { getDashboardStats } from "@/api/admin"
import type { DashboardStats } from "@/types/models"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL, ROUTES } from "@/lib/constants"
import { cn, formatNumber } from "@/lib/utils"
import { useLanguage } from "@/providers/language-provider"
import {
  Users,
  UserCog,
  DollarSign,
  CreditCard,
  ShieldAlert,
  RefreshCw,
  AlertCircle,
  ArrowUpRight,
  TrendingUp,
  Activity,
  User,
  CheckCircle,
  ArrowRight,
} from "lucide-react"
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  BarChart,
  Bar,
  Cell,
} from "recharts"

const mockWeekData = [
  { day: "Mon", revenue: 4200, trips: 240 },
  { day: "Tue", revenue: 3800, trips: 189 },
  { day: "Wed", revenue: 5100, trips: 310 },
  { day: "Thu", revenue: 4780, trips: 390 },
  { day: "Fri", revenue: 6890, trips: 480 },
  { day: "Sat", revenue: 8390, trips: 680 },
  { day: "Sun", revenue: 9490, trips: 730 },
]

interface KpiCardProps {
  label: string
  value: React.ReactNode
  icon: React.ComponentType<{ className?: string }>
  iconBg: string
  iconColor: string
  onClick: () => void
  badge?: string
  badgeColor?: string
  index: number
}

function KpiCard({ label, value, icon: Icon, iconBg, iconColor, onClick, badge, badgeColor, index }: KpiCardProps) {
  return (
    <button
      onClick={onClick}
      className="group w-full text-left bg-white rounded-2xl p-5 shadow-sm border border-border/60 hover:shadow-md hover:-translate-y-0.5 transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/50"
      style={{ animationDelay: `${index * 80}ms` }}
    >
      <div className="flex items-start justify-between mb-4">
        <div className={cn("w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0", iconBg)}>
          <Icon className={cn("w-5 h-5", iconColor)} />
        </div>
        {badge && (
          <span className={cn("text-[11px] font-semibold px-2 py-0.5 rounded-full", badgeColor)}>
            {badge}
          </span>
        )}
        <ArrowUpRight className="w-4 h-4 text-muted-foreground/40 group-hover:text-primary group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-all duration-200" />
      </div>
      <div className="space-y-1">
        <p className="text-2xl font-bold text-foreground tracking-tight leading-none">{value}</p>
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">{label}</p>
      </div>
    </button>
  )
}

interface OperationRowProps {
  label: string
  desc: string
  value: React.ReactNode
  icon: React.ComponentType<{ className?: string }>
  alert?: boolean
  onClick: () => void
}

function OperationRow({ label, desc, value, icon: Icon, alert, onClick }: OperationRowProps) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "group w-full flex items-center gap-4 p-4 rounded-xl border transition-all duration-200 hover:-translate-y-0.5",
        alert
          ? "bg-rose-50 border-rose-200/60 hover:border-rose-300 hover:shadow-sm"
          : "bg-white border-border/60 hover:border-border hover:shadow-sm"
      )}
    >
      <div className={cn(
        "w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 transition-transform duration-200 group-hover:scale-110",
        alert ? "bg-rose-100 text-rose-600" : "bg-muted text-muted-foreground group-hover:bg-primary/10 group-hover:text-primary"
      )}>
        <Icon className="w-4 h-4" />
      </div>
      <div className="flex-1 text-left min-w-0">
        <p className={cn("text-sm font-semibold leading-none mb-0.5", alert ? "text-rose-700" : "text-foreground")}>{label}</p>
        <p className="text-xs text-muted-foreground truncate">{desc}</p>
      </div>
      <div className={cn("text-xl font-black tabular-nums", alert ? "text-rose-600" : "text-foreground")}>
        {value}
      </div>
      <ArrowRight className={cn("w-4 h-4 flex-shrink-0 transition-all duration-200 group-hover:translate-x-0.5", alert ? "text-rose-400" : "text-muted-foreground/40 group-hover:text-primary")} />
    </button>
  )
}

export default function DashboardPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { t, language } = useLanguage()
  const isRtl = language === "ar"

  const {
    data: stats,
    isLoading,
    isError,
    error,
    refetch,
    isFetching,
  } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS],
    queryFn: getDashboardStats,
    refetchInterval: DASHBOARD_REFRESH_INTERVAL,
    staleTime: DASHBOARD_REFRESH_INTERVAL / 2,
  })

  const skeleton = <div className="h-7 w-20 animate-pulse rounded-lg bg-muted" />

  const val = (key: keyof DashboardStats, currency = false) => {
    if (isLoading || stats === undefined) return skeleton
    const n = stats?.[key] ?? 0
    return <>{currency && "$"}{formatNumber(n as number)}</>
  }

  if (isError) {
    return (
      <div className="space-y-5 animate-in fade-in duration-300">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">{t("dashboardTitle")}</h1>
          <p className="text-muted-foreground text-sm mt-1">{t("dashboardSubtitle")}</p>
        </div>
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>{t("errorLoadingStats")}</AlertTitle>
          <AlertDescription className="mt-2 flex flex-col gap-2">
            <p>{error instanceof Error ? error.message : t("failedToFetchStats")}</p>
            <button
              onClick={() => refetch()}
              className="flex items-center gap-1.5 w-fit text-sm font-semibold text-destructive hover:underline"
            >
              <RefreshCw className="w-3.5 h-3.5" /> {t("tryAgain")}
            </button>
          </AlertDescription>
        </Alert>
      </div>
    )
  }

  const kpiCards: KpiCardProps[] = [
    {
      label: t("totalRevenue"),
      value: val("totalRevenue", true),
      icon: DollarSign,
      iconBg: "bg-emerald-100",
      iconColor: "text-emerald-600",
      onClick: () => navigate(ROUTES.REPORTS),
      badge: "+12%",
      badgeColor: "bg-emerald-100 text-emerald-700",
      index: 0,
    },
    {
      label: t("activeTrips"),
      value: val("activeTrips"),
      icon: Activity,
      iconBg: "bg-blue-100",
      iconColor: "text-blue-600",
      onClick: () => navigate(ROUTES.TRIPS),
      badge: t("liveTracking"),
      badgeColor: "bg-blue-100 text-blue-700",
      index: 1,
    },
    {
      label: t("totalUsers"),
      value: val("totalUsers"),
      icon: Users,
      iconBg: "bg-violet-100",
      iconColor: "text-violet-600",
      onClick: () => navigate(ROUTES.USERS),
      index: 2,
    },
    {
      label: t("totalDrivers"),
      value: val("totalDrivers"),
      icon: UserCog,
      iconBg: "bg-orange-100",
      iconColor: "text-orange-600",
      onClick: () => navigate(ROUTES.USERS),
      index: 3,
    },
  ]

  const operationRows: OperationRowProps[] = [
    {
      label: t("totalPassengers"),
      desc: t("registeredAccounts"),
      value: isLoading ? "-" : formatNumber(stats?.totalPassengers ?? 0),
      icon: User,
      onClick: () => navigate(ROUTES.USERS),
    },
    {
      label: t("completedTrips"),
      desc: t("successfullyFinished"),
      value: isLoading ? "-" : formatNumber(stats?.completedTrips ?? 0),
      icon: CheckCircle,
      onClick: () => navigate(ROUTES.TRIPS),
    },
    {
      label: t("pendingPayments"),
      desc: t("awaitingSettlement"),
      value: isLoading ? "-" : formatNumber(stats?.pendingPayments ?? 0),
      icon: CreditCard,
      onClick: () => navigate(ROUTES.PAYMENTS_PENDING),
    },
    {
      label: t("walletTopup"),
      desc: t("awaitingSettlement"),
      value: isLoading ? "-" : formatNumber(stats?.pendingManualTopups ?? 0),
      icon: CreditCard,
      onClick: () => navigate(`${ROUTES.PAYMENTS}?type=wallet_topup&method=manual&status=pending`),
    },
    {
      label: t("unverifiedVehicles"),
      desc: t("needsAdminReview"),
      value: isLoading ? "-" : formatNumber(stats?.pendingVehicleVerifications ?? 0),
      icon: ShieldAlert,
      alert: Number(stats?.pendingVehicleVerifications) > 0,
      onClick: () => navigate(ROUTES.VEHICLES),
    },
  ]

  return (
    <div className="space-y-7 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-8">

      {/* Page Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-[22px] font-bold tracking-tight text-foreground leading-tight">
            {t("dashboardTitle")}
          </h1>
          <p className="text-sm text-muted-foreground mt-0.5">{t("dashboardSubtitle")}</p>
        </div>
        <div className="flex items-center gap-3">
          {stats && (
            <div className={cn(
              "hidden sm:flex items-center gap-2 text-xs font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200/70 px-3 py-1.5 rounded-full"
            )}>
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-500" />
              </span>
              {t("liveTracking")}
            </div>
          )}
          <button
            onClick={() => queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS] })}
            disabled={isFetching}
            className={cn(
              "flex items-center gap-2 h-9 px-4 rounded-full text-sm font-semibold transition-all duration-200",
              "bg-white border border-border/70 shadow-sm hover:shadow hover:border-border text-foreground/80 hover:text-foreground",
              isFetching && "opacity-60 cursor-not-allowed"
            )}
          >
            <RefreshCw className={cn("h-3.5 w-3.5", isFetching && "animate-spin")} />
            {isFetching ? t("refreshing") : t("refreshData")}
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid gap-4 grid-cols-1 sm:grid-cols-2 xl:grid-cols-4">
        {kpiCards.map((card) => (
          <KpiCard key={card.label} {...card} />
        ))}
      </div>

      {/* Chart + Operations */}
      <div className="grid gap-5 lg:grid-cols-5">

        {/* Revenue Chart */}
        <div className="lg:col-span-3 bg-white rounded-2xl border border-border/60 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between px-6 py-4 border-b border-border/50">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-xl bg-indigo-50 flex items-center justify-center">
                <TrendingUp className="w-4 h-4 text-indigo-600" />
              </div>
              <div>
                <p className="text-sm font-bold text-foreground">{t("platformGrowth")}</p>
                <p className="text-xs text-muted-foreground">{t("revenueMomentum")}</p>
              </div>
            </div>
            <span className="text-[11px] font-semibold text-muted-foreground bg-muted px-2.5 py-1 rounded-full">
              {t("weeklyOverview")}
            </span>
          </div>

          {/* Area Chart */}
          <div className="px-4 pt-4 pb-2 h-[260px]">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={mockWeekData} margin={{ top: 5, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="gradRevenue" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#4f46e5" stopOpacity={0.25} />
                    <stop offset="100%" stopColor="#4f46e5" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                <XAxis
                  dataKey="day"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fontSize: 11, fill: "#94a3b8", fontWeight: 600 }}
                  dy={8}
                />
                <YAxis
                  axisLine={false}
                  tickLine={false}
                  orientation={isRtl ? "right" : "left"}
                  tick={{ fontSize: 11, fill: "#94a3b8", fontWeight: 600 }}
                  tickFormatter={(v) => `$${v / 1000}k`}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: "12px",
                    border: "1px solid #e2e8f0",
                    boxShadow: "0 4px 20px rgba(0,0,0,0.08)",
                    backgroundColor: "#fff",
                    fontSize: "12px",
                    fontWeight: 600,
                  }}
                  itemStyle={{ color: "#4f46e5" }}
                  formatter={(v) => [`$${Number(v ?? 0).toLocaleString()}`, "Revenue"]}
                />
                <Area
                  type="monotone"
                  dataKey="revenue"
                  stroke="#4f46e5"
                  strokeWidth={2.5}
                  fill="url(#gradRevenue)"
                  dot={{ r: 3, fill: "#4f46e5", strokeWidth: 0 }}
                  activeDot={{ r: 5, fill: "#4f46e5" }}
                  animationDuration={1200}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          {/* Bar Chart - Trips */}
          <div className="px-4 pb-4 h-[120px]">
            <p className="text-[10px] font-bold uppercase tracking-widest text-muted-foreground/60 mb-2 pl-1">
              {t("activeTrips")}
            </p>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={mockWeekData} margin={{ top: 0, right: 10, left: -20, bottom: 0 }} barSize={18}>
                <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{ fontSize: 10, fill: "#cbd5e1" }} dy={6} />
                <Tooltip
                  contentStyle={{ borderRadius: "10px", border: "1px solid #e2e8f0", fontSize: "12px", fontWeight: 600 }}
                  itemStyle={{ color: "#10b981" }}
                  formatter={(v) => [Number(v ?? 0), "Trips"]}
                />
                <Bar dataKey="trips" radius={[4, 4, 0, 0]}>
                  {mockWeekData.map((_, i) => (
                    <Cell
                      key={`cell-${i}`}
                      fill={i === mockWeekData.length - 1 ? "#10b981" : "#d1fae5"}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Operations Panel */}
        <div className="lg:col-span-2 flex flex-col gap-3">
          <div className="flex items-center justify-between px-1">
            <p className="text-sm font-bold text-foreground">{t("operations")}</p>
          </div>
          <div className="flex flex-col gap-2.5">
            {operationRows.map((row) => (
              <OperationRow key={row.label} {...row} />
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
