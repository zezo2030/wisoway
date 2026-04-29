// T043 — AccountFlagsPage
//
// Displays security flags raised by the platform (multi-account device,
// repeated mock location, etc.) and lets admins resolve or dismiss them.
//
// API: GET /admin/account-flags, PATCH /admin/account-flags/:id/resolve,
//      PATCH /admin/account-flags/:id/dismiss

import { useState } from "react"
import { useSearchParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { ShieldAlert, CheckCircle2, XCircle } from "lucide-react"
import { useLanguage } from "@/providers/language-provider"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { DataTable } from "@/components/data-table"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { QUERY_KEYS } from "@/lib/constants"
import {
  getAccountFlags,
  resolveAccountFlag,
  dismissAccountFlag,
  type GetAccountFlagsParams,
} from "@/api/admin"
import type { AccountFlag, AccountFlagSeverity, AccountFlagDisposition } from "@/types/models"
import type { Column } from "@/components/data-table"

const SEVERITY_COLORS: Record<AccountFlagSeverity, string> = {
  low:      "bg-blue-50 text-blue-700 border-blue-200",
  medium:   "bg-yellow-50 text-yellow-700 border-yellow-200",
  high:     "bg-orange-50 text-orange-700 border-orange-200",
  critical: "bg-red-50 text-red-700 border-red-200",
}

const DISPOSITION_COLORS: Record<AccountFlagDisposition, string> = {
  open:      "bg-slate-100 text-slate-700 border-slate-200",
  resolved:  "bg-green-50 text-green-700 border-green-200",
  dismissed: "bg-gray-50 text-gray-500 border-gray-200",
}

interface ConfirmState {
  open: boolean
  title: string
  description: string
  variant?: "default" | "destructive"
  onConfirm: () => void
}

export default function AccountFlagsPage() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const { t } = useLanguage()

  const page = parseInt(searchParams.get("page") || "1", 10)
  const disposition = (searchParams.get("disposition") || "") as GetAccountFlagsParams["disposition"] | ""
  const severity = searchParams.get("severity") || ""

  const [confirm, setConfirm] = useState<ConfirmState>({
    open: false,
    title: "",
    description: "",
    onConfirm: () => {},
  })

  function updateParams(updates: Record<string, string>) {
    const next = new URLSearchParams(searchParams)
    Object.entries(updates).forEach(([k, v]) => {
      if (v) next.set(k, v)
      else next.delete(k)
    })
    setSearchParams(next)
  }

  const { data, isLoading } = useQuery({
    queryKey: [QUERY_KEYS.ACCOUNT_FLAGS.LIST, { page, disposition, severity }],
    queryFn: () =>
      getAccountFlags({
        page,
        limit: 20,
        ...(disposition ? { disposition } : {}),
        ...(severity ? { severity } : {}),
      }),
  })

  const resolveMutation = useMutation({
    mutationFn: (flagId: string) => resolveAccountFlag(flagId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ACCOUNT_FLAGS.LIST] })
      toast.success(t("flagResolved"))
    },
    onError: () => toast.error(t("noData")),
  })

  const dismissMutation = useMutation({
    mutationFn: (flagId: string) => dismissAccountFlag(flagId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ACCOUNT_FLAGS.LIST] })
      toast.success(t("flagDismissed"))
    },
    onError: () => toast.error(t("noData")),
  })

  function handleResolve(flag: AccountFlag) {
    setConfirm({
      open: true,
      title: t("flagResolveConfirmTitle"),
      description: t("flagResolveConfirmDesc"),
      variant: "default",
      onConfirm: () => {
        resolveMutation.mutate(flag.id)
        setConfirm((s) => ({ ...s, open: false }))
      },
    })
  }

  function handleDismiss(flag: AccountFlag) {
    setConfirm({
      open: true,
      title: t("flagDismissConfirmTitle"),
      description: t("flagDismissConfirmDesc"),
      variant: "destructive",
      onConfirm: () => {
        dismissMutation.mutate(flag.id)
        setConfirm((s) => ({ ...s, open: false }))
      },
    })
  }

  function getUserName(flag: AccountFlag): string {
    if (typeof flag.userId === "object" && flag.userId !== null) {
      return (flag.userId as { name?: string }).name ?? flag.userId.toString()
    }
    return flag.userId as string
  }

  function getReasonLabel(reason: string): string {
    const map: Record<string, () => string> = {
      multi_account_device: () => t("flagReason_multi_account_device"),
      mock_location_repeated: () => t("flagReason_mock_location_repeated"),
    }
    return map[reason]?.() ?? reason
  }

  const columns: Column<AccountFlag>[] = [
    {
      key: "userId",
      header: t("flagUser"),
      cell: (flag) => (
        <button
          className="text-primary hover:underline text-sm font-medium"
          onClick={(e) => {
            e.stopPropagation()
            const userId = typeof flag.userId === "object"
              ? (flag.userId as { _id?: string })._id
              : flag.userId
            if (userId) navigate(`/users/${userId}`)
          }}
        >
          {getUserName(flag)}
        </button>
      ),
    },
    {
      key: "reason",
      header: t("flagReason"),
      cell: (flag) => (
        <span className="text-sm">{getReasonLabel(flag.reason)}</span>
      ),
    },
    {
      key: "severity",
      header: t("flagSeverity"),
      cell: (flag) => {
        const severityLabels: Record<AccountFlagSeverity, () => string> = {
          low: () => t("flagSeverity_low"),
          medium: () => t("flagSeverity_medium"),
          high: () => t("flagSeverity_high"),
          critical: () => t("flagSeverity_critical"),
        }
        return (
          <Badge variant="outline" className={SEVERITY_COLORS[flag.severity] ?? ""}>
            {severityLabels[flag.severity]?.() ?? flag.severity}
          </Badge>
        )
      },
    },
    {
      key: "disposition",
      header: t("flagDisposition"),
      cell: (flag) => {
        const dispositionLabels: Record<AccountFlagDisposition, () => string> = {
          open: () => t("flagDisposition_open"),
          resolved: () => t("flagDisposition_resolved"),
          dismissed: () => t("flagDisposition_dismissed"),
        }
        return (
          <Badge variant="outline" className={DISPOSITION_COLORS[flag.disposition] ?? ""}>
            {dispositionLabels[flag.disposition]?.() ?? flag.disposition}
          </Badge>
        )
      },
    },
    {
      key: "createdAt",
      header: t("flagCreatedAt"),
      cell: (flag) => (
        <span className="text-sm text-muted-foreground">
          {new Date(flag.createdAt).toLocaleDateString()}
        </span>
      ),
    },
    {
      key: "id",
      header: t("actions"),
      cell: (flag) =>
        flag.disposition === "open" ? (
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              variant="outline"
              className="text-green-700 border-green-200 hover:bg-green-50"
              onClick={(e) => {
                e.stopPropagation()
                handleResolve(flag)
              }}
              disabled={resolveMutation.isPending || dismissMutation.isPending}
            >
              <CheckCircle2 className="h-4 w-4 mr-1" />
              {t("flagResolve")}
            </Button>
            <Button
              size="sm"
              variant="outline"
              className="text-muted-foreground"
              onClick={(e) => {
                e.stopPropagation()
                handleDismiss(flag)
              }}
              disabled={resolveMutation.isPending || dismissMutation.isPending}
            >
              <XCircle className="h-4 w-4 mr-1" />
              {t("flagDismiss")}
            </Button>
          </div>
        ) : (
          <span className="text-xs text-muted-foreground capitalize">
            {flag.disposition}
          </span>
        ),
    },
  ]

  return (
    <div className="space-y-8 animate-in fade-in duration-300">
      {/* Page Header */}
      <div className="flex items-center gap-3">
        <div className="p-2 rounded-lg bg-destructive/10">
          <ShieldAlert className="h-6 w-6 text-destructive" />
        </div>
        <div>
          <h1 className="text-2xl font-bold tracking-tight">{t("accountFlagsTitle")}</h1>
          <p className="text-muted-foreground text-sm">{t("accountFlagsSubtitle")}</p>
        </div>
      </div>

      {/* Filters + Table */}
      <Card>
        <CardHeader className="pb-4">
          <div className="flex flex-wrap gap-3">
            {/* Disposition filter */}
            <Select
              value={disposition || "all"}
              onValueChange={(v) =>
                updateParams({ disposition: v === "all" ? "" : v, page: "1" })
              }
            >
              <SelectTrigger className="w-44">
                <SelectValue placeholder={t("allDispositions")} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t("allDispositions")}</SelectItem>
                <SelectItem value="open">{t("flagDisposition_open")}</SelectItem>
                <SelectItem value="resolved">{t("flagDisposition_resolved")}</SelectItem>
                <SelectItem value="dismissed">{t("flagDisposition_dismissed")}</SelectItem>
              </SelectContent>
            </Select>

            {/* Severity filter */}
            <Select
              value={severity || "all"}
              onValueChange={(v) =>
                updateParams({ severity: v === "all" ? "" : v, page: "1" })
              }
            >
              <SelectTrigger className="w-44">
                <SelectValue placeholder={t("allSeverities")} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">{t("allSeverities")}</SelectItem>
                <SelectItem value="low">{t("flagSeverity_low")}</SelectItem>
                <SelectItem value="medium">{t("flagSeverity_medium")}</SelectItem>
                <SelectItem value="high">{t("flagSeverity_high")}</SelectItem>
                <SelectItem value="critical">{t("flagSeverity_critical")}</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          <DataTable
            columns={columns}
            data={data?.data ?? []}
            page={page}
            totalPages={data?.meta?.totalPages ?? 0}
            onPageChange={(p) => updateParams({ page: String(p) })}
            loading={isLoading}
          />
        </CardContent>
      </Card>

      <ConfirmDialog
        open={confirm.open}
        onOpenChange={(open) => !open && setConfirm((s) => ({ ...s, open: false }))}
        title={confirm.title}
        description={confirm.description}
        variant={confirm.variant}
        onConfirm={confirm.onConfirm}
      />
    </div>
  )
}
