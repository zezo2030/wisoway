// Pending Charges Page: Admin view of outstanding late-cancellation / no-show charges
// Phase 4 / T085 — 008-platform-completion

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getPendingCharges, waivePendingCharge } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL } from "@/lib/constants"
import { formatDate, formatPhone } from "@/lib/utils"
import type { PendingCharge, UserSummary } from "@/types/models"
import { ReceiptText, AlertCircle, ShieldOff } from "lucide-react"
import { toast } from "sonner"
import { useLanguage } from "@/providers/language-provider"

function isPopulatedUser(val: string | UserSummary): val is UserSummary {
    return typeof val === "object" && val !== null && "name" in val
}

const KIND_LABELS: Record<string, string> = {
    late_cancellation: "Late Cancellation",
    passenger_no_show: "Passenger No-Show",
    driver_no_show: "Driver No-Show",
}

const STATUS_FILTER_OPTIONS = [
    { value: "all", label: "All Statuses" },
    { value: "pending", label: "Pending" },
    { value: "collected", label: "Collected" },
    { value: "waived", label: "Waived" },
    { value: "failed", label: "Failed" },
] as const

export default function PendingChargesPage() {
    const [searchParams, setSearchParams] = useSearchParams()
    const queryClient = useQueryClient()
    const { t } = useLanguage()
    const page = parseInt(searchParams.get("page") || "1", 10)
    const status = searchParams.get("status") as "pending" | "collected" | "waived" | "failed" | undefined || undefined
    const limit = 20

    const [confirmDialog, setConfirmDialog] = useState<{
        open: boolean
        charge: PendingCharge | null
    }>({ open: false, charge: null })

    const { data, isLoading, error } = useQuery({
        queryKey: [QUERY_KEYS.PENDING_CHARGES.LIST, { page, limit, status }],
        queryFn: () => getPendingCharges({ page, limit, status }),
        refetchInterval: DASHBOARD_REFRESH_INTERVAL,
    })

    const waiveMutation = useMutation({
        mutationFn: (chargeId: string) => waivePendingCharge(chargeId),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.PENDING_CHARGES.LIST] })
            toast.success("Charge waived successfully")
            setConfirmDialog({ open: false, charge: null })
        },
        onError: () => {
            toast.error("Failed to waive charge")
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

    const columns: Column<PendingCharge>[] = [
        {
            key: "user",
            header: "User",
            cell: (charge) => (
                <div className="flex items-center gap-3 py-1">
                    {isPopulatedUser(charge.userId) ? (
                        <>
                            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm border border-primary/20 flex-shrink-0">
                                {charge.userId.name.charAt(0).toUpperCase()}
                            </div>
                            <div>
                                <div className="font-semibold text-sm">{charge.userId.name}</div>
                                <div className="text-xs text-muted-foreground" dir={charge.userId.phoneNumber ? "ltr" : undefined}>{charge.userId.phoneNumber ? formatPhone(charge.userId.phoneNumber) : charge.userId.email}</div>
                            </div>
                        </>
                    ) : (
                        <span className="text-muted-foreground font-mono text-xs">ID: {charge.userId}</span>
                    )}
                </div>
            ),
        },
        {
            key: "kind",
            header: "Reason",
            cell: (charge) => (
                <span className="text-sm font-medium">
                    {KIND_LABELS[charge.kind] ?? charge.kind}
                </span>
            ),
        },
        {
            key: "amount",
            header: "Amount",
            cell: (charge) => (
                <span className="font-mono font-bold text-sm">
                    {charge.amount.toFixed(2)} {charge.currency}
                </span>
            ),
        },
        {
            key: "status",
            header: "Status",
            cell: (charge) => (
                <StatusBadge
                    status={charge.status}
                    type="payment"
                    className="shadow-sm"
                />
            ),
        },
        {
            key: "created",
            header: "Created",
            cell: (charge) => (
                <span className="text-sm text-muted-foreground whitespace-nowrap">
                    {formatDate(charge.createdAt)}
                </span>
            ),
        },
        {
            key: "actions",
            header: "Actions",
            className: "w-[110px]",
            cell: (charge) => (
                <div onClick={(e) => e.stopPropagation()}>
                    {charge.status === "pending" && (
                        <Button
                            size="sm"
                            variant="outline"
                            className="text-xs font-semibold"
                            onClick={() => setConfirmDialog({ open: true, charge })}
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
                <h1 className="text-4xl font-extrabold tracking-tight">Pending Charges</h1>
                <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
                    <AlertCircle className="w-6 h-6 mr-3" />
                    <span className="font-semibold text-lg">Failed to load pending charges. Please try again.</span>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
            <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
                <div className="flex items-center gap-4">
                    <div className="bg-amber-500/10 p-3 rounded-2xl border border-amber-500/20 shadow-sm hidden sm:block">
                        <ReceiptText className="w-8 h-8 text-amber-500" />
                    </div>
                    <div>
                        <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">
                            Pending Charges
                        </h1>
                        <p className="text-muted-foreground mt-1 text-lg font-medium">
                            Late-cancellation and no-show fees awaiting collection.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
                <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
                    <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
                        <h2 className="text-xl font-bold flex items-center">
                            <ReceiptText className="w-5 h-5 mr-3 text-amber-500" />
                            All Pending Charges
                        </h2>
                        <div className="flex items-center gap-3">
                            <Select value={status || "all"} onValueChange={handleStatusFilter}>
                                <SelectTrigger className="w-[160px]">
                                    <SelectValue placeholder="Filter by status" />
                                </SelectTrigger>
                                <SelectContent>
                                    {STATUS_FILTER_OPTIONS.map((opt) => (
                                        <SelectItem key={opt.value} value={opt.value}>
                                            {opt.label}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                            <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                                <span className="text-muted-foreground">Total:</span>{" "}
                                <span className="text-foreground ml-1">{data?.meta?.total ?? 0}</span>
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
                            emptyMessage={t("noPendingChargesFound")}
                        />
                    </div>
                </CardContent>
            </Card>

            <ConfirmDialog
                open={confirmDialog.open}
                onOpenChange={(open) => setConfirmDialog((prev) => ({ ...prev, open }))}
                title="Waive Charge"
                description="Are you sure you want to waive this charge? The user will not be billed."
                variant="default"
                onConfirm={() => {
                    if (confirmDialog.charge) {
                        waiveMutation.mutate(confirmDialog.charge.id)
                    }
                }}
                loading={waiveMutation.isPending}
            />
        </div>
    )
}
