// Reports Page: Revenue, user growth, and trip activity reports
// T034: Implements reports with date range picker and charts

import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { getReport } from "@/api/admin"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Calendar } from "@/components/ui/calendar"
import { QUERY_KEYS, DEFAULT_REPORT_DAYS } from "@/lib/constants"
import { formatCurrency, formatNumber, cn } from "@/lib/utils"
import type { ReportResponse } from "@/types/models"
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
} from "recharts"
import { CalendarIcon, TrendingUp, Users, Car, DollarSign, AlertCircle, BarChart3, Activity } from "lucide-react"
import { format, subDays, isAfter } from "date-fns"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"

export default function ReportsPage() {
  const { t } = useLanguage()
  const [reportType, setReportType] = useState<"revenue" | "users" | "trips">("revenue")
  const [startDate, setStartDate] = useState<Date>(subDays(new Date(), DEFAULT_REPORT_DAYS))
  const [endDate, setEndDate] = useState<Date>(new Date())
  const [startDateOpen, setStartDateOpen] = useState(false)
  const [endDateOpen, setEndDateOpen] = useState(false)

  // Validate dates
  const validateDates = () => {
    if (isAfter(startDate, endDate)) {
      toast.error(t("startDateBeforeEnd"))
      return false
    }
    return true
  }

  // Fetch report data
  const { data: report, isLoading, error } = useQuery({
    queryKey: [
      QUERY_KEYS.ADMIN.REPORTS,
      { type: reportType, startDate: format(startDate, "yyyy-MM-dd"), endDate: format(endDate, "yyyy-MM-dd") },
    ],
    queryFn: () =>
      getReport({
        type: reportType,
        startDate: format(startDate, "yyyy-MM-dd"),
        endDate: format(endDate, "yyyy-MM-dd"),
      }),
    enabled: validateDates(),
  })

  // Prepare chart data
  const chartData = report?.breakdown.map((item) => ({
    date: item.date,
    value: item.amount ?? item.count,
    displayDate: format(new Date(item.date), "MMM d"),
  }))

  // Get summary title and icon based on report type
  const getSummaryConfig = () => {
    switch (reportType) {
      case "revenue":
        return {
          title: t("totalRevenueGenerated"),
          icon: DollarSign,
          value: report?.summary.total ?? 0,
          prefix: "",
          suffix: "",
          currency: true,
          color: "emerald"
        }
      case "users":
        return {
          title: t("totalNewUsers"),
          icon: Users,
          value: report?.summary.count ?? 0,
          prefix: "",
          suffix: "",
          currency: false,
          color: "blue"
        }
      case "trips":
        return {
          title: t("totalTripsCount"),
          icon: Car,
          value: report?.summary.count ?? 0,
          prefix: "",
          suffix: "",
          currency: false,
          color: "indigo"
        }
    }
  }

  const summaryConfig = getSummaryConfig()
  const SummaryIcon = summaryConfig.icon

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("reportsTitle")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className="w-6 h-6 mr-3" />
          <span className="font-semibold text-lg">{t("failedToLoadReports")}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">

      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
            <BarChart3 className="w-8 h-8 text-primary" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">{t("analyticsReports")}</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("reportsSubtitle")}
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col xl:flex-row gap-6 justify-between items-start xl:items-center">
            {/* Report Type Tabs */}
            <Tabs value={reportType} onValueChange={(value) => setReportType(value as typeof reportType)} className="w-full xl:w-auto">
              <TabsList className="bg-background/80 p-1.5 rounded-2xl border border-border/40 shadow-sm w-full sm:w-auto h-auto min-w-min flex overflow-x-auto overflow-y-hidden justify-start">
                <TabsTrigger value="revenue" className="rounded-xl px-4 py-2 font-bold text-sm transition-all data-[state=active]:bg-emerald-500 data-[state=active]:text-white flex-shrink-0">
                  <DollarSign className="mr-2 h-4 w-4" /> {t("revenueReport")}
                </TabsTrigger>
                <TabsTrigger value="users" className="rounded-xl px-4 py-2 font-bold text-sm transition-all data-[state=active]:bg-blue-500 data-[state=active]:text-white flex-shrink-0">
                  <Users className="mr-2 h-4 w-4" /> {t("usersTitle")}
                </TabsTrigger>
                <TabsTrigger value="trips" className="rounded-xl px-4 py-2 font-bold text-sm transition-all data-[state=active]:bg-indigo-500 data-[state=active]:text-white flex-shrink-0">
                  <Car className="mr-2 h-4 w-4" /> {t("tripsTitle")}
                </TabsTrigger>
              </TabsList>
            </Tabs>

            {/* Date Range Picker */}
            <div className="flex flex-wrap items-center gap-3 w-full xl:w-auto">
              <div className="flex items-center gap-2 w-full sm:w-auto">
                <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground hidden sm:block">{t("from")}:</span>
                <Popover open={startDateOpen} onOpenChange={setStartDateOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      className="w-full sm:w-[150px] justify-start text-left font-medium bg-background/50 border-border/50 shadow-sm rounded-xl hover:bg-muted"
                    >
                      <CalendarIcon className="mr-2 h-4 w-4 text-primary" />
                      {format(startDate, "MMM d, yyyy")}
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0 rounded-xl border-border/50 shadow-xl" align="end">
                    <Calendar
                      mode="single"
                      selected={startDate}
                      onSelect={(date) => {
                        if (date) {
                          setStartDate(date)
                          setStartDateOpen(false)
                        }
                      }}
                      initialFocus
                      className="rounded-xl"
                    />
                  </PopoverContent>
                </Popover>
              </div>

              <div className="flex items-center justify-center shrink-0 w-8 sm:w-auto text-muted-foreground/30">
                —
              </div>

              <div className="flex items-center gap-2 w-full sm:w-auto">
                <span className="text-xs font-bold uppercase tracking-wider text-muted-foreground hidden sm:block">{t("to")}:</span>
                <Popover open={endDateOpen} onOpenChange={setEndDateOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      variant="outline"
                      className="w-full sm:w-[150px] justify-start text-left font-medium bg-background/50 border-border/50 shadow-sm rounded-xl hover:bg-muted"
                    >
                      <CalendarIcon className="mr-2 h-4 w-4 text-primary" />
                      {format(endDate, "MMM d, yyyy")}
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-auto p-0 rounded-xl border-border/50 shadow-xl" align="end">
                    <Calendar
                      mode="single"
                      selected={endDate}
                      onSelect={(date) => {
                        if (date) {
                          setEndDate(date)
                          setEndDateOpen(false)
                        }
                      }}
                      initialFocus
                      className="rounded-xl"
                    />
                  </PopoverContent>
                </Popover>
              </div>
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-6">
          <Tabs value={reportType}>
            <TabsContent value={reportType} className="mt-0">
              <ReportContent
                report={report}
                isLoading={isLoading}
                startDate={startDate}
                endDate={endDate}
                summaryConfig={summaryConfig}
                SummaryIcon={SummaryIcon}
                chartData={chartData}
                reportType={reportType}
              />
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  )
}

// Report content component
interface ReportContentProps {
  report: ReportResponse | undefined
  isLoading: boolean
  startDate: Date
  endDate: Date
  summaryConfig: {
    title: string
    value: number
    prefix: string
    suffix: string
    currency: boolean
    color: string
  }
  SummaryIcon: React.ComponentType<{ className?: string }>
  chartData: { date: string; value: number; displayDate: string }[] | undefined
  reportType: "revenue" | "users" | "trips"
}

function ReportContent({
  report,
  isLoading,
  startDate,
  endDate,
  summaryConfig,
  SummaryIcon,
  chartData,
  reportType,
}: ReportContentProps) {
  const { t } = useLanguage()

  // Dynamic color configuration
  const getColorScheme = () => {
    switch (reportType) {
      case 'revenue': return { main: '#10b981', light: 'bg-emerald-50 dark:bg-emerald-950/30', border: 'border-emerald-100 dark:border-emerald-900', text: 'text-emerald-600 dark:text-emerald-400' }
      case 'users': return { main: '#3b82f6', light: 'bg-blue-50 dark:bg-blue-950/30', border: 'border-blue-100 dark:border-blue-900', text: 'text-blue-600 dark:text-blue-400' }
      case 'trips': return { main: '#6366f1', light: 'bg-indigo-50 dark:bg-indigo-950/30', border: 'border-indigo-100 dark:border-indigo-900', text: 'text-indigo-600 dark:text-indigo-400' }
    }
  }

  const scheme = getColorScheme();

  return (
    <div className="space-y-6">
      {/* Summary Cards */}
      {report && (
        <div className="grid gap-6 md:grid-cols-2">
          <Card className={cn("border shadow-sm relative overflow-hidden", scheme.border, scheme.light)}>
            <div className={cn("absolute top-0 right-0 w-32 h-32 rounded-full blur-3xl opacity-20 -mr-10 -mt-10 pointer-events-none", `bg-[${scheme.main}]`)} />
            <CardContent className="p-6 relative z-10 flex items-center justify-between">
              <div>
                <p className="text-sm font-bold uppercase tracking-wider text-muted-foreground/80 mb-1">{summaryConfig.title}</p>
                <div className={cn("text-4xl font-black", scheme.text)}>
                  {summaryConfig.currency
                    ? formatCurrency(summaryConfig.value, "JOD")
                    : formatNumber(summaryConfig.value)}
                </div>
                <p className="text-xs font-medium text-foreground/50 mt-2">
                  <span className="font-semibold">{format(startDate, "MMM d, yyyy")}</span> {t("to")} <span className="font-semibold">{format(endDate, "MMM d, yyyy")}</span>
                </p>
              </div>
              <div className={cn("p-4 rounded-2xl bg-background/50 backdrop-blur-sm shadow-sm border border-white/20", scheme.text)}>
                <SummaryIcon className="h-8 w-8" />
              </div>
            </CardContent>
          </Card>

          <Card className="border-border/50 shadow-sm bg-muted/20 relative overflow-hidden group">
            <CardContent className="p-6 flex items-center justify-between">
              <div>
                <p className="text-sm font-bold uppercase tracking-wider text-muted-foreground/80 mb-1">{t("dailyAverage")}</p>
                <div className="text-3xl font-bold text-foreground">
                  {summaryConfig.currency
                    ? formatCurrency(
                      summaryConfig.value / (report.breakdown.length || 1),
                      "JOD"
                    )
                    : formatNumber(
                      Math.round(summaryConfig.value / (report.breakdown.length || 1))
                    )}
                </div>
                <p className="text-xs font-medium text-muted-foreground mt-2">
                  {t("perDayOver")} <span className="font-semibold text-foreground/80">{report.breakdown.length} {t("days")}</span>
                </p>
              </div>
              <div className="p-4 rounded-2xl bg-background shadow-sm border border-border/40 text-muted-foreground group-hover:scale-105 transition-transform duration-300">
                <TrendingUp className="h-8 w-8" />
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Chart */}
      <Card className="border-border/50 shadow-sm bg-card overflow-hidden">
        <CardHeader className="border-b border-border/40 pb-4 bg-muted/10">
          <div className="flex items-center gap-2">
            <Activity className={cn("w-5 h-5", scheme.text)} />
            <CardTitle className="text-lg font-bold">{t("trendAnalysis")}</CardTitle>
          </div>
        </CardHeader>
        <CardContent className="p-6 pt-8">
          {isLoading ? (
            <div className="h-[350px] animate-pulse rounded-2xl bg-muted/50 w-full flex items-center justify-center">
              <div className="flex flex-col items-center gap-3">
                <Activity className="w-8 h-8 text-muted-foreground/30 animate-bounce" />
                <span className="text-sm font-semibold text-muted-foreground/50">{t("analyzingData")}</span>
              </div>
            </div>
          ) : chartData && chartData.length > 0 ? (
            <div className="h-[350px] w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorValue" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={scheme.main} stopOpacity={0.3} />
                      <stop offset="95%" stopColor={scheme.main} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border) / 0.5)" />
                  <XAxis
                    dataKey="displayDate"
                    tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))", fontWeight: 500 }}
                    tickLine={false}
                    axisLine={false}
                    interval="preserveStartEnd"
                    dy={10}
                  />
                  <YAxis
                    tick={{ fontSize: 12, fill: "hsl(var(--muted-foreground))", fontWeight: 500 }}
                    tickLine={false}
                    axisLine={false}
                    dx={-10}
                    tickFormatter={(value) =>
                      summaryConfig.currency
                        ? `${Math.round(value).toLocaleString()}`
                        : value.toLocaleString()
                    }
                  />
                  <RechartsTooltip
                    contentStyle={{
                      backgroundColor: 'hsl(var(--background))',
                      borderRadius: '12px',
                      border: '1px solid hsl(var(--border))',
                      boxShadow: '0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)',
                      padding: '12px 16px',
                      fontWeight: 600
                    }}
                    itemStyle={{ color: scheme.main, fontSize: '15px' }}
                    labelStyle={{ color: 'hsl(var(--muted-foreground))', fontSize: '12px', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '0.05em' }}
                    formatter={(value) => {
                      const numValue = typeof value === 'number' ? value : 0
                      return [summaryConfig.currency
                        ? formatCurrency(numValue, "JOD")
                        : formatNumber(numValue), ""]
                    }}
                    labelFormatter={(label) => `${label}`}
                  />
                  <Area
                    type="monotone"
                    dataKey="value"
                    stroke={scheme.main}
                    strokeWidth={3}
                    fillOpacity={1}
                    fill="url(#colorValue)"
                    activeDot={{ r: 6, fill: scheme.main, stroke: "hsl(var(--background))", strokeWidth: 2 }}
                  />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div className="h-[350px] w-full rounded-2xl border border-dashed border-border/50 flex flex-col items-center justify-center text-center">
              <div className="bg-muted p-4 rounded-full mb-4">
                <AlertCircle className="w-8 h-8 text-muted-foreground" />
              </div>
              <h3 className="text-lg font-bold">{t("noDataFound")}</h3>
              <p className="text-muted-foreground text-sm max-w-[250px] mt-1 font-medium">{t("noActivityInRange")}</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Breakdown Table */}
      {report && report.breakdown.length > 0 && (
        <Card className="border-border/50 shadow-sm bg-card overflow-hidden">
          <CardHeader className="border-b border-border/40 pb-4 bg-muted/10">
            <CardTitle className="text-lg font-bold">{t("detailedBreakdown")}</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
              <Table>
                <TableHeader className="bg-muted/30">
                  <TableRow className="hover:bg-transparent">
                    <TableHead className="font-bold">{t("date")}</TableHead>
                    <TableHead className="text-right font-bold w-[250px]">
                      {reportType === "revenue" ? t("amountGenerated") : t("count")}
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {report.breakdown.map((item) => {
                    const value = reportType === "revenue" && item.amount ? item.amount : item.count;
                    if (value === 0) return null; // Skip days with 0 activity

                    return (
                      <TableRow key={item.date} className="hover:bg-muted/30 transition-colors">
                        <TableCell className="font-medium">
                          {format(new Date(item.date), "MMMM d, yyyy")}
                        </TableCell>
                        <TableCell className="text-right">
                          <span className={cn(
                            "font-bold text-sm bg-muted/50 px-3 py-1.5 rounded-md border border-border/30 inline-block min-w-[100px] text-center",
                            value > 0 && scheme.text
                          )}>
                            {reportType === "revenue" && item.amount
                              ? formatCurrency(item.amount, "JOD")
                              : formatNumber(item.count)}
                          </span>
                        </TableCell>
                      </TableRow>
                    )
                  })}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  )
}
