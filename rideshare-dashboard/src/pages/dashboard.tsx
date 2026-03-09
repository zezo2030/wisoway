import { useQuery, useQueryClient } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import { getDashboardStats } from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL, ROUTES } from "@/lib/constants"
import { cn, formatNumber } from "@/lib/utils"
import {
  Users,
  UserCog,
  User,
  CheckCircle,
  DollarSign,
  CreditCard,
  ShieldAlert,
  RefreshCw,
  AlertCircle,
  ArrowRight,
  TrendingUp,
  Activity,
  Zap
} from "lucide-react"
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts"

// Illustrative mock data for the growth chart showing a positive trend
const mockChartData = [
  { name: "Mon", revenue: 4200, trips: 240 },
  { name: "Tue", revenue: 3800, trips: 189 },
  { name: "Wed", revenue: 5100, trips: 310 },
  { name: "Thu", revenue: 4780, trips: 390 },
  { name: "Fri", revenue: 6890, trips: 480 },
  { name: "Sat", revenue: 8390, trips: 680 },
  { name: "Sun", revenue: 9490, trips: 730 },
]

export default function DashboardPage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

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

  // Primary stats meant to grab immediate attention with premium gradients
  const primaryStats = [
    {
      key: "totalRevenue" as const,
      title: "Total Revenue",
      icon: DollarSign,
      route: ROUTES.REPORTS,
      color: "from-emerald-500 to-teal-400",
      gradient: "bg-gradient-to-br",
      textColor: "text-emerald-500",
      bgLight: "bg-emerald-50 dark:bg-emerald-500/10",
      isCurrency: true
    },
    {
      key: "activeTrips" as const,
      title: "Active Trips",
      icon: Activity,
      route: ROUTES.TRIPS,
      color: "from-blue-500 to-indigo-500",
      gradient: "bg-gradient-to-br",
      textColor: "text-blue-500",
      bgLight: "bg-blue-50 dark:bg-blue-500/10",
      isCurrency: false
    },
    {
      key: "totalUsers" as const,
      title: "Total Users",
      icon: Users,
      route: ROUTES.USERS,
      color: "from-violet-500 to-purple-500",
      gradient: "bg-gradient-to-br",
      textColor: "text-violet-500",
      bgLight: "bg-violet-50 dark:bg-violet-500/10",
      isCurrency: false
    },
    {
      key: "totalDrivers" as const,
      title: "Total Drivers",
      icon: UserCog,
      route: ROUTES.USERS,
      color: "from-orange-500 to-rose-400",
      gradient: "bg-gradient-to-br",
      textColor: "text-orange-500",
      bgLight: "bg-orange-50 dark:bg-orange-500/10",
      isCurrency: false
    },
  ]

  // Secondary operational stats focused on list format
  const secondaryStats = [
    {
      key: "totalPassengers" as const,
      title: "Total Passengers",
      icon: User,
      route: ROUTES.USERS,
      desc: "Registered passenger accounts",
    },
    {
      key: "completedTrips" as const,
      title: "Completed Trips",
      icon: CheckCircle,
      route: ROUTES.TRIPS,
      desc: "Successfully finished trips",
    },
    {
      key: "pendingPayments" as const,
      title: "Pending Payments",
      icon: CreditCard,
      route: ROUTES.PAYMENTS_PENDING,
      desc: "Awaiting settlement",
    },
    {
      key: "pendingVehicleVerifications" as const,
      title: "Unverified Vehicles",
      icon: ShieldAlert,
      route: ROUTES.VEHICLES,
      desc: "Needs admin review",
      alert: true,
    },
  ]

  if (isError) {
    return (
      <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
        <div>
          <h1 className="text-4xl font-extrabold tracking-tight">Overview Dashboard</h1>
          <p className="text-muted-foreground mt-1 text-lg">Platform overview and key metrics</p>
        </div>
        <Alert variant="destructive" className="border-red-500/50 bg-red-50 dark:bg-red-900/10">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Error loading dashboard stats</AlertTitle>
          <AlertDescription className="flex flex-col gap-3 mt-2">
            <p>{error instanceof Error ? error.message : "Failed to fetch dashboard statistics"}</p>
            <Button variant="outline" size="sm" onClick={() => refetch()} className="w-fit border-red-200 hover:bg-red-100 text-red-700 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-900/30">
              <RefreshCw className="mr-2 h-4 w-4" /> Try Again
            </Button>
          </AlertDescription>
        </Alert>
      </div>
    )
  }

  const renderStatValue = (val: number | undefined, isCurrency = false) => {
    if (isLoading || val === undefined) return <div className="h-8 w-24 animate-pulse rounded-md bg-muted/60" />
    return (
      <span className="text-3xl font-bold tracking-tight text-foreground">
        {isCurrency ? "$" : ""}{formatNumber(val)}
      </span>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">

      {/* Header section with live indicator */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
            Overview Dashboard
          </h1>
          <p className="text-muted-foreground mt-1.5 text-lg font-medium">
            Good to see you! Here's what's happening today.
          </p>
        </div>
        <div className="flex items-center gap-4">
          {stats && (
            <div className="hidden sm:flex items-center text-sm font-semibold text-muted-foreground bg-muted/30 px-4 py-2 rounded-full border border-border/40 backdrop-blur-md shadow-sm">
              <span className="relative flex h-2.5 w-2.5 mr-2.5">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
              </span>
              Live Tracking
            </div>
          )}
          <Button
            variant="outline"
            className="rounded-full shadow-sm hover:shadow-md transition-all duration-300 border-primary/20 hover:border-primary/50 font-semibold"
            onClick={() => queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS] })}
            disabled={isFetching}
          >
            <RefreshCw className={cn("mr-2 h-4 w-4 text-primary", isFetching && "animate-spin")} />
            {isFetching ? "Refreshing..." : "Refresh Data"}
          </Button>
        </div>
      </div>

      {/* Hero / Primary Metrics */}
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        {primaryStats.map((stat, idx) => {
          const Icon = stat.icon
          const value = stats?.[stat.key]

          return (
            <Card
              key={stat.key}
              className={cn(
                "group relative overflow-hidden transition-all duration-500 hover:-translate-y-1.5 hover:shadow-xl cursor-pointer border-none bg-background/60 backdrop-blur-2xl shadow-lg dark:shadow-none dark:bg-card/40 dark:border dark:border-white/10"
              )}
              onClick={() => navigate(stat.route)}
              style={{ animationFillMode: "both", animationDelay: `${idx * 100}ms` }}
            >
              <div className={cn("absolute inset-0 opacity-[0.08] transition-opacity duration-500 group-hover:opacity-[0.2]", stat.gradient, stat.color)} />
              <div className="absolute top-0 right-0 p-4 opacity-[0.15] transform translate-x-4 -translate-y-4 group-hover:scale-110 group-hover:-rotate-12 transition-transform duration-700 ease-out">
                <Icon className={cn("w-24 h-24", stat.textColor)} />
              </div>
              <CardContent className="p-6">
                <div className="flex items-center justify-between mb-5">
                  <div className={cn("p-3.5 rounded-2xl shadow-sm transition-transform duration-300 group-hover:scale-110", stat.bgLight)}>
                    <Icon className={cn("w-6 h-6", stat.textColor)} />
                  </div>
                  <div className="text-muted-foreground bg-background/50 rounded-full p-2 opacity-0 -translate-x-4 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-300 shadow-sm border border-border/50">
                    <ArrowRight className="w-4 h-4" />
                  </div>
                </div>
                <div className="space-y-1">
                  <p className="text-sm font-semibold text-muted-foreground uppercase tracking-wider">{stat.title}</p>
                  <div className="flex items-baseline space-x-2">
                    {renderStatValue(value, stat.isCurrency)}
                  </div>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>

      <div className="grid gap-6 md:grid-cols-7 lg:gap-8">
        {/* Main Chart Section */}
        <Card className="md:col-span-4 lg:col-span-5 overflow-hidden border-border/50 shadow-lg bg-card/60 backdrop-blur-xl transition-all duration-300 hover:shadow-xl dark:shadow-none dark:border-white/10">
          <CardHeader className="flex flex-row items-center justify-between border-b border-border/30 bg-muted/10 pb-4 pt-5 px-6">
            <div className="space-y-1.5">
              <CardTitle className="text-xl font-bold flex items-center tracking-tight">
                <div className="p-2 bg-primary/10 rounded-lg mr-3">
                  <TrendingUp className="w-5 h-5 text-primary" />
                </div>
                Platform Growth (Simulated)
              </CardTitle>
              <p className="text-sm text-muted-foreground font-medium">Revenue momentum past 7 days</p>
            </div>
            <div className="hidden sm:block bg-background px-3 py-1.5 rounded-full text-xs font-bold text-primary shadow-sm border border-border/50">
              Weekly Overview
            </div>
          </CardHeader>
          <CardContent className="p-6">
            <div className="h-[320px] w-full mt-2">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={mockChartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#4f46e5" stopOpacity={0.4} />
                      <stop offset="95%" stopColor="#818cf8" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="currentColor" className="text-muted opacity-20" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: 'currentColor', fontSize: 13, fontWeight: 500 }} className="text-muted-foreground" dy={15} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fill: 'currentColor', fontSize: 13, fontWeight: 500 }} className="text-muted-foreground" dx={-15} tickFormatter={(val) => `$${val / 1000}k`} />
                  <Tooltip
                    contentStyle={{ borderRadius: '16px', border: '1px solid rgba(255,255,255,0.1)', boxShadow: '0 20px 25px -5px rgb(0 0 0 / 0.1)', backgroundColor: 'var(--card)', color: 'var(--foreground)', fontWeight: 600, padding: '12px 16px' }}
                    itemStyle={{ color: '#4f46e5', fontWeight: 700 }}
                  />
                  <Area type="monotone" dataKey="revenue" stroke="#4f46e5" strokeWidth={4} fill="url(#colorRevenue)" animationDuration={1500} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Secondary Metrics Column */}
        <div className="md:col-span-3 lg:col-span-2 space-y-5 flex flex-col justify-between">
          <h3 className="font-bold text-xl flex items-center px-1 text-foreground/90 tracking-tight">
            <div className="p-2 bg-amber-500/10 rounded-lg mr-3">
              <Zap className="w-5 h-5 text-amber-500 drop-shadow-sm" />
            </div>
            Operations
          </h3>
          <div className="grid gap-4 flex-1">
            {secondaryStats.map((stat, idx) => {
              const Icon = stat.icon
              const value = stats?.[stat.key]
              const hasAlert = stat.alert && Number(value) > 0;

              return (
                <Card
                  key={stat.key}
                  className={cn(
                    "group cursor-pointer hover:-translate-y-1 hover:shadow-lg transition-all duration-300 bg-card/60 backdrop-blur-xl border-border/40 shadow-sm",
                    hasAlert && "border-rose-500/30 bg-rose-50/40 dark:bg-rose-900/10 shadow-rose-500/10"
                  )}
                  onClick={() => navigate(stat.route)}
                  style={{ animationFillMode: "both", animationDelay: `${idx * 150 + 400}ms` }}
                >
                  <CardContent className="p-5 flex items-center justify-between">
                    <div className="flex items-center space-x-4">
                      <div className={cn(
                        "p-3 rounded-xl transition-all duration-300 group-hover:scale-110",
                        hasAlert ? "bg-rose-100/80 text-rose-600 dark:bg-rose-900/50 dark:text-rose-400 shadow-inner" : "bg-muted text-muted-foreground group-hover:bg-primary/10 group-hover:text-primary shadow-inner"
                      )}>
                        <Icon className="w-5 h-5" />
                      </div>
                      <div className="space-y-0.5">
                        <p className={cn("text-sm font-bold leading-none", hasAlert && "text-rose-700 dark:text-rose-300")}>{stat.title}</p>
                        <p className="text-xs font-medium text-muted-foreground/80">{stat.desc}</p>
                      </div>
                    </div>
                    <div className={cn(
                      "text-2xl font-black tracking-tight pl-3",
                      hasAlert ? "text-rose-600 dark:text-rose-400" : "text-foreground"
                    )}>
                      {isLoading ? "-" : formatNumber(value ?? 0)}
                    </div>
                  </CardContent>
                </Card>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
