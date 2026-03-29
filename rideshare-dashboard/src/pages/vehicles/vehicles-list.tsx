// Vehicles List Page: Vehicle verification workflow
// T028: Implements vehicle list with verify/reject actions and license preview

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getVehicles, verifyVehicle } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { StatusBadge } from "@/components/status-badge"
import { ImagePreview } from "@/components/image-preview"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL } from "@/lib/constants"
import { formatDate, cn } from "@/lib/utils"
import type { Vehicle, UserSummary } from "@/types/models"
import { useLanguage } from "@/providers/language-provider"
import { CheckCircle, XCircle, FileText, AlertCircle, Car, ShieldCheck } from "lucide-react"
import { toast } from "sonner"

// Type guard for populated fields
function isPopulatedDriver(driverId: string | UserSummary): driverId is UserSummary {
  return typeof driverId === "object" && driverId !== null && "name" in driverId
}

export default function VehiclesListPage() {
  const { t, language } = useLanguage()
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const page = parseInt(searchParams.get("page") || "1", 10)
  const limit = 20

  // Confirmation dialog state
  const [confirmDialog, setConfirmDialog] = useState<{
    open: boolean
    vehicle: Vehicle | null
    action: "verify" | "reject" | null
  }>({
    open: false,
    vehicle: null,
    action: null,
  })

  // Fetch vehicles
  const { data, isLoading, error } = useQuery({
    queryKey: [QUERY_KEYS.ADMIN.VEHICLES, { page, limit }],
    queryFn: () => getVehicles({ page, limit }),
    refetchInterval: DASHBOARD_REFRESH_INTERVAL,
  })

  // Verify mutation
  const verifyMutation = useMutation({
    mutationFn: ({ vehicleId, isVerified }: { vehicleId: string; isVerified: boolean }) =>
      verifyVehicle(vehicleId, isVerified),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.VEHICLES] })
      queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.DASHBOARD_STATS] })
      toast.success(variables.isVerified ? t("userConfirmed") : t("driverRejected"))
      setConfirmDialog({ open: false, vehicle: null, action: null })
    },
    onError: () => {
      toast.error("Failed to update vehicle status")
    },
  })

  const handlePageChange = (newPage: number) => {
    const newParams = new URLSearchParams(searchParams)
    newParams.set("page", String(newPage))
    setSearchParams(newParams)
  }

  const openConfirmDialog = (vehicle: Vehicle, action: "verify" | "reject") => {
    setConfirmDialog({
      open: true,
      vehicle,
      action,
    })
  }

  const handleConfirmAction = () => {
    if (!confirmDialog.vehicle || !confirmDialog.action) return

    const isVerified = confirmDialog.action === "verify"
    // Support both TypeORM (id) and MongoDB (_id) response formats
    const vehicleId =
      (confirmDialog.vehicle as { id?: string; _id: string }).id ??
      confirmDialog.vehicle._id
    verifyMutation.mutate({
      vehicleId,
      isVerified,
    })
  }

  // Check if file is PDF
  const isPdf = (url: string) => url.toLowerCase().endsWith(".pdf")

  // Table columns
  const columns: Column<Vehicle>[] = [
    {
      key: "driver",
      header: t("driver"),
      cell: (vehicle) => (
        <div className="flex items-center gap-3 py-1">
          {isPopulatedDriver(vehicle.driverId) ? (
            <>
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/10 text-primary font-bold text-sm shadow-sm border border-primary/20 flex-shrink-0">
                {vehicle.driverId.name.charAt(0).toUpperCase()}
              </div>
              <div>
                <div className="font-semibold text-foreground">{vehicle.driverId.name}</div>
                <div className="text-xs font-medium text-muted-foreground">{vehicle.driverId.email}</div>
              </div>
            </>
          ) : (
            <span className="text-muted-foreground font-mono text-xs">ID: {vehicle.driverId}</span>
          )}
        </div>
      ),
    },
    {
      key: "type",
      header: t("vehicleInfo"),
      cell: (vehicle) => (
        <div className="flex flex-col gap-0.5">
          <div className="capitalize font-semibold text-foreground">{vehicle.vehicleType}</div>
          <div className="text-xs font-medium text-muted-foreground">{vehicle.model}</div>
        </div>
      )
    },
    {
      key: "plate",
      header: t("plateNumber"),
      cell: (vehicle) => (
        <div className="font-mono font-bold tracking-wider text-sm bg-muted/60 px-2.5 py-1 rounded w-fit border border-border/40 text-foreground">
          {vehicle.plateNumber}
        </div>
      ),
    },
    {
      key: "seats",
      header: t("seats"),
      cell: (vehicle) => <div className="font-semibold text-foreground">{vehicle.seats}</div>,
    },
    {
      key: "licenseImage",
      header: t("driverLicense"),
      cell: (vehicle) => (
        <div className="flex items-center gap-2">
          {isPdf(vehicle.licenseImageUrl) ? (
            <a
              href={vehicle.licenseImageUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-blue-600 bg-blue-50 dark:bg-blue-950/30 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/50 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
              onClick={(e) => e.stopPropagation()}
            >
              <FileText className="h-4 w-4" />
              PDF Document
            </a>
          ) : (
            <ImagePreview
              imageUrl={vehicle.licenseImageUrl}
              alt={t("driverLicense")}
              thumbnailClassName="h-12 w-12 sm:h-14 sm:w-14 rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:scale-105 transition-transform"
            />
          )}
        </div>
      ),
    },
    {
      key: "vehicleLicense",
      header: t("vehicleReg"),
      cell: (vehicle) => (
        <div className="flex items-center gap-2">
          {isPdf(vehicle.vehicleLicenseImageUrl) ? (
            <a
              href={vehicle.vehicleLicenseImageUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-blue-600 bg-blue-50 dark:bg-blue-950/30 px-3 py-1.5 rounded-lg border border-blue-200 dark:border-blue-900/50 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
              onClick={(e) => e.stopPropagation()}
            >
              <FileText className="h-4 w-4" />
              PDF Document
            </a>
          ) : (
            <ImagePreview
              imageUrl={vehicle.vehicleLicenseImageUrl}
              alt={t("vehicleReg")}
              thumbnailClassName="h-12 w-12 sm:h-14 sm:w-14 rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:scale-105 transition-transform"
            />
          )}
        </div>
      ),
    },
    {
      key: "status",
      header: t("status"),
      cell: (vehicle) => (
        <StatusBadge
          status={vehicle.isVerified ? "verified" : "unverified"}
          type="vehicle"
          className="shadow-sm"
        />
      ),
    },
    {
      key: "submitted",
      header: t("date"),
      cell: (vehicle) => <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">{formatDate(vehicle.createdAt)}</div>,
    },
    {
      key: "actions",
      header: t("actions"),
      className: "w-[170px]",
      cell: (vehicle) => (
        <div className="flex flex-col sm:flex-row gap-2" onClick={(e) => e.stopPropagation()}>
          {!vehicle.isVerified && (
            <Button
              size="sm"
              variant="default"
              className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs shadow-md shadow-emerald-600/20 w-fit"
              onClick={() => openConfirmDialog(vehicle, "verify")}
              disabled={verifyMutation.isPending}
            >
              <CheckCircle className={cn("h-3.5 w-3.5", language === "ar" ? "ml-1.5" : "mr-1.5")} />
              {t("verify")}
            </Button>
          )}
          <Button
            size="sm"
            variant={vehicle.isVerified ? "outline" : "destructive"}
            className="font-semibold text-xs shadow-sm w-fit"
            onClick={() => openConfirmDialog(vehicle, vehicle.isVerified ? "reject" : "reject")}
            disabled={verifyMutation.isPending}
          >
            <XCircle className={cn("h-3.5 w-3.5", language === "ar" ? "ml-1.5" : "mr-1.5")} />
            {vehicle.isVerified ? t("revoke") : t("reject")}
          </Button>
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">{t("nav_vehicles")}</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className={cn("w-6 h-6", language === "ar" ? "ml-3" : "mr-3")} />
          <span className="font-semibold text-lg">{t("failedToFetchStats")}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
      <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="bg-primary/10 p-3 rounded-2xl border border-primary/20 shadow-sm hidden sm:block">
            <ShieldCheck className="w-8 h-8 text-primary" />
          </div>
          <div>
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">{t("vehicleRegistration")}</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              {t("vehiclesSubtitle")}
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <h2 className="text-xl font-bold flex items-center">
              <Car className={cn("w-5 h-5 text-primary", language === "ar" ? "ml-3" : "mr-3")} />
              {t("verificationQueue")}
            </h2>
            <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
              <span className="text-muted-foreground">{t("totalDisplayed")}:</span> <span className="text-foreground ml-1">{data?.data?.length || 0}</span>
            </div>
          </div>
        </CardHeader>

        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <DataTable
              columns={columns}
              data={data?.data || []}
              page={page}
              totalPages={data?.meta.totalPages || 0}
              total={data?.meta.total || 0}
              onPageChange={handlePageChange}
              pageSize={limit}
              loading={isLoading}
              emptyMessage={t("noVehiclesPending")}
            />
          </div>
        </CardContent>
      </Card>

      {/* Confirmation Dialog */}
      <ConfirmDialog
        open={confirmDialog.open}
        onOpenChange={(open) =>
          setConfirmDialog((prev) => ({ ...prev, open }))
        }
        title={
          confirmDialog.action === "verify"
            ? t("verifyConfirmTitle")
            : confirmDialog.vehicle?.isVerified
              ? t("revokeConfirmTitle")
              : t("rejectConfirmTitle")
        }
        description={
          confirmDialog.action === "verify"
            ? t("verifyConfirmDesc")
            : confirmDialog.vehicle?.isVerified
              ? t("revokeConfirmDesc")
              : t("rejectConfirmDesc")
        }
        variant={confirmDialog.action === "reject" || (confirmDialog.action === "reject" && confirmDialog.vehicle?.isVerified) ? "destructive" : "default"}
        onConfirm={handleConfirmAction}
        loading={verifyMutation.isPending}
      />
    </div>
  )
}
