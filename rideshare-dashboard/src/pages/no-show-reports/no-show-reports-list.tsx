import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { getNoShowReports } from "@/api/admin"
import type { NoShowReport } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatPhone } from "@/lib/utils"
import { AlertTriangle, Gavel, AlertCircle, CheckCircle2 } from "lucide-react"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"
import { CreateFineDialog } from "../fines/create-fine-dialog"

export default function NoShowReportsPage() {
  const { t } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const filter = searchParams.get("filter") ?? "all"
  const limit = 20

  const [fineTarget, setFineTarget] = useState<NoShowReport | null>(null)

  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.NO_SHOW_REPORTS.LIST, { page, limit, filter }],
    queryFn: () =>
      getNoShowReports({
        page,
        limit,
        majorityOnly: filter === "majority",
        unfinedOnly: filter === "unfined",
      }),
  })

  const handlePageChange = (newPage: number) => {
    const p = new URLSearchParams(searchParams)
    p.set("page", String(newPage))
    setSearchParams(p)
  }

  const handleFilterChange = (value: string) => {
    const p = new URLSearchParams(searchParams)
    if (value === "all") {
      p.delete("filter")
    } else {
      p.set("filter", value)
    }
    p.set("page", "1")
    setSearchParams(p)
  }

  const columns: Column<NoShowReport>[] = [
    {
      key: "driver",
      header: t("fineDriver"),
      cell: (r) => (
        <div className="py-1">
          <div className="font-semibold text-sm">
            {r.driverName ?? r.driverId.slice(0, 8)}
          </div>
          {r.driverPhone && (
            <div className="text-xs text-muted-foreground" dir="ltr">
              {formatPhone(r.driverPhone)}
            </div>
          )}
        </div>
      ),
    },
    {
      key: "route",
      header: t("noShowReportsColTrip"),
      cell: (r) => (
        <div className="text-sm">
          <div className="font-medium">{r.fromName}</div>
          <div className="text-muted-foreground">↓ {r.toName}</div>
          <div className="text-xs text-muted-foreground mt-1 whitespace-nowrap">
            {formatDate(r.departureTime)}
          </div>
        </div>
      ),
    },
    {
      key: "reports",
      header: t("noShowReportsColReports"),
      cell: (r) => (
        <div className="flex flex-col gap-1 text-sm">
          <div className="flex items-center gap-1.5">
            <AlertTriangle className="h-3.5 w-3.5 text-amber-500" />
            <span className="font-mono font-semibold">
              {r.reportedAbsenceCount}
            </span>
            <span className="text-muted-foreground">/ {r.confirmedPassengers}</span>
            <span className="text-xs text-muted-foreground">
              {t("noShowReportsReportedSuffix")}
            </span>
          </div>
          {r.confirmedPresenceCount > 0 && (
            <div className="flex items-center gap-1.5 text-xs">
              <CheckCircle2 className="h-3 w-3 text-emerald-500" />
              <span>
                {r.confirmedPresenceCount} {t("noShowReportsConfirmedPresent")}
              </span>
            </div>
          )}
        </div>
      ),
    },
    {
      key: "severity",
      header: t("status"),
      cell: (r) => (
        <div className="flex flex-col gap-1">
          {r.majorityReached ? (
            <Badge variant="destructive" className="w-fit">
              {t("noShowReportsMajority")}
            </Badge>
          ) : (
            <Badge variant="outline" className="w-fit">
              {t("noShowReportsSingleReport")}
            </Badge>
          )}
          {r.fineIssued && (
            <Badge variant="secondary" className="w-fit">
              {t("noShowReportsFineIssuedBadge")}
            </Badge>
          )}
        </div>
      ),
    },
    {
      key: "time",
      header: t("noShowReportsColFirstReport"),
      cell: (r) => (
        <span className="text-xs text-muted-foreground whitespace-nowrap">
          {r.earliestReportAt ? formatDate(r.earliestReportAt) : "—"}
        </span>
      ),
    },
    {
      key: "actions",
      header: t("actions"),
      className: "w-[130px]",
      cell: (r) => (
        <div onClick={(e) => e.stopPropagation()}>
          {!r.fineIssued ? (
            <Button
              size="sm"
              variant="default"
              className="text-xs font-semibold"
              onClick={() => setFineTarget(r)}
            >
              <Gavel className="mr-1.5 h-3.5 w-3.5" />
              {t("createFine")}
            </Button>
          ) : (
            <span className="text-xs text-muted-foreground">
              {t("noShowReportsDone")}
            </span>
          )}
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">
          {t("noShowReportsTitle")}
        </h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className="w-6 h-6 mr-3" />
          <span className="font-semibold text-lg">
            {t("noShowReportsLoadError")}
          </span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-amber-500/10 p-3 rounded-2xl border border-amber-500/20 shadow-sm hidden sm:block">
            <AlertTriangle className="w-8 h-8 text-amber-500" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
              {t("noShowReportsTitle")}
            </h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("noShowReportsSubtitle")}
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <h2 className="text-xl font-bold flex items-center">
              <AlertTriangle className="w-5 h-5 mr-3 text-amber-500" />
              {t("noShowReportsCardTitle")}
            </h2>
            <div className="flex items-center gap-3">
              <Select value={filter} onValueChange={handleFilterChange}>
                <SelectTrigger className="w-[180px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">
                    {t("noShowReportsFilterAll")}
                  </SelectItem>
                  <SelectItem value="majority">
                    {t("noShowReportsFilterMajority")}
                  </SelectItem>
                  <SelectItem value="unfined">
                    {t("noShowReportsFilterUnfined")}
                  </SelectItem>
                </SelectContent>
              </Select>
              <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                <span className="text-muted-foreground">{t("total")}:</span>{" "}
                <span className="text-foreground ml-1">
                  {data?.meta?.total ?? 0}
                </span>
              </div>
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <DataTable
              columns={columns}
              data={data?.data ?? []}
              page={page}
              totalPages={data?.meta.totalPages ?? 0}
              total={data?.meta.total ?? 0}
              onPageChange={handlePageChange}
              pageSize={limit}
              loading={isLoading}
              emptyMessage={t("noShowReportsEmpty")}
            />
          </div>
        </CardContent>
      </Card>

      <CreateFineDialog
        open={fineTarget !== null}
        onOpenChange={(open) => {
          if (!open) setFineTarget(null)
        }}
        driverId={fineTarget?.driverId}
        tripId={fineTarget?.tripId}
        onCreated={() => {
          queryClient.invalidateQueries({
            queryKey: [QUERY_KEYS.NO_SHOW_REPORTS.LIST],
          })
          queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.FINES.LIST] })
          toast.success(t("fineCreated"))
          setFineTarget(null)
        }}
      />
    </div>
  )
}
