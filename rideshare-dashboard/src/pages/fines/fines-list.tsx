import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getFines, waiveFine } from "@/api/admin"
import type { Fine } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { QUERY_KEYS } from "@/lib/constants"
import { formatDate, formatPhone } from "@/lib/utils"
import { Gavel, AlertCircle, ShieldOff, Plus } from "lucide-react"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"
import { CreateFineDialog } from "./create-fine-dialog"

export default function FinesPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const { t } = useLanguage()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const status =
    (searchParams.get("status") as "pending" | "applied" | "waived" | null) ??
    undefined
  const limit = 20

  const [waiveTarget, setWaiveTarget] = useState<Fine | null>(null)
  const [createOpen, setCreateOpen] = useState(false)

  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.FINES.LIST, { page, limit, status }],
    queryFn: () => getFines({ page, limit, status: status ?? undefined }),
  })

  const waiveMutation = useMutation({
    mutationFn: (fineId: string) => waiveFine(fineId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.FINES.LIST] })
      toast.success(t("fineWaived"))
      setWaiveTarget(null)
    },
    onError: () => {
      toast.error("Failed to waive fine")
    },
  })

  const handlePageChange = (newPage: number) => {
    const p = new URLSearchParams(searchParams)
    p.set("page", String(newPage))
    setSearchParams(p)
  }

  const handleStatusFilter = (value: string) => {
    const p = new URLSearchParams(searchParams)
    if (value === "all") {
      p.delete("status")
    } else {
      p.set("status", value)
    }
    p.set("page", "1")
    setSearchParams(p)
  }

  const columns: Column<Fine>[] = [
    {
      key: "driver",
      header: t("fineDriver"),
      cell: (fine) => (
        <div className="py-1">
          <div className="font-semibold text-sm">
            {fine.driver.name ?? fine.userId}
          </div>
          {fine.driver.phone && (
            <div className="text-xs text-muted-foreground" dir="ltr">
              {formatPhone(fine.driver.phone)}
            </div>
          )}
        </div>
      ),
    },
    {
      key: "reason",
      header: t("fineReason"),
      cell: (fine) => (
        <div className="max-w-[320px] text-sm">
          <div className="line-clamp-2">{fine.reason ?? "—"}</div>
        </div>
      ),
    },
    {
      key: "amount",
      header: t("fineAmount"),
      cell: (fine) => (
        <span className="font-mono font-bold text-sm">
          {Number(fine.amount).toFixed(2)}
        </span>
      ),
    },
    {
      key: "status",
      header: "Status",
      cell: (fine) => (
        <StatusBadge status={fine.status} type="payment" className="shadow-sm" />
      ),
    },
    {
      key: "created",
      header: "Created",
      cell: (fine) => (
        <span className="text-sm text-muted-foreground whitespace-nowrap">
          {formatDate(fine.createdAt)}
        </span>
      ),
    },
    {
      key: "actions",
      header: "Actions",
      className: "w-[110px]",
      cell: (fine) => (
        <div onClick={(e) => e.stopPropagation()}>
          {fine.status === "pending" && (
            <Button
              size="sm"
              variant="outline"
              className="text-xs font-semibold"
              onClick={() => setWaiveTarget(fine)}
              disabled={waiveMutation.isPending}
            >
              <ShieldOff className="mr-1.5 h-3.5 w-3.5" />
              Waive
            </Button>
          )}
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">
          {t("finesTitle")}
        </h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className="w-6 h-6 mr-3" />
          <span className="font-semibold text-lg">
            Failed to load fines. Please try again.
          </span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-rose-500/10 p-3 rounded-2xl border border-rose-500/20 shadow-sm hidden sm:block">
            <Gavel className="w-8 h-8 text-rose-500" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
              {t("finesTitle")}
            </h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("finesSubtitle")}
            </p>
          </div>
        </div>
        <Button onClick={() => setCreateOpen(true)} className="gap-2">
          <Plus className="w-4 h-4" />
          {t("createFine")}
        </Button>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <h2 className="text-xl font-bold flex items-center">
              <Gavel className="w-5 h-5 mr-3 text-rose-500" />
              {t("finesTitle")}
            </h2>
            <div className="flex items-center gap-3">
              <Select
                value={status || "all"}
                onValueChange={handleStatusFilter}
              >
                <SelectTrigger className="w-[160px]">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All</SelectItem>
                  <SelectItem value="pending">
                    {t("fineStatus_pending")}
                  </SelectItem>
                  <SelectItem value="applied">
                    {t("fineStatus_applied")}
                  </SelectItem>
                  <SelectItem value="waived">
                    {t("fineStatus_waived")}
                  </SelectItem>
                </SelectContent>
              </Select>
              <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                <span className="text-muted-foreground">Total:</span>{" "}
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
              emptyMessage="No fines found."
            />
          </div>
        </CardContent>
      </Card>

      <ConfirmDialog
        open={waiveTarget !== null}
        onOpenChange={(open) => {
          if (!open) setWaiveTarget(null)
        }}
        title={t("waiveFineConfirmTitle")}
        description={t("waiveFineConfirmDesc")}
        variant="default"
        onConfirm={() => {
          if (waiveTarget) waiveMutation.mutate(waiveTarget.id)
        }}
        loading={waiveMutation.isPending}
      />

      <CreateFineDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onCreated={() => {
          queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.FINES.LIST] })
          toast.success(t("fineCreated"))
          setCreateOpen(false)
        }}
      />
    </div>
  )
}
