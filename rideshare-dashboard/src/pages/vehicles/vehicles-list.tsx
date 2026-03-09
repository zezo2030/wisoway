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
import { formatDate } from "@/lib/utils"
import type { Vehicle, UserSummary } from "@/types/models"
import { CheckCircle, XCircle, FileText, AlertCircle, Car, ShieldCheck } from "lucide-react"
import { toast } from "sonner"

// Type guard for populated fields
function isPopulatedDriver(driverId: string | UserSummary): driverId is UserSummary {
  return typeof driverId === "object" && driverId !== null && "name" in driverId
}

export default function VehiclesListPage() {
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
      toast.success(variables.isVerified ? "Vehicle verified successfully" : "Vehicle rejected")
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
      header: "Driver",
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
      header: "Vehicle Info",
      cell: (vehicle) => (
        <div className="flex flex-col gap-0.5">
          <div className="capitalize font-semibold text-foreground">{vehicle.vehicleType}</div>
          <div className="text-xs font-medium text-muted-foreground">{vehicle.model}</div>
        </div>
      )
    },
    {
      key: "plate",
      header: "Plate Number",
      cell: (vehicle) => (
        <div className="font-mono font-bold tracking-wider text-sm bg-muted/60 px-2.5 py-1 rounded w-fit border border-border/40 text-foreground">
          {vehicle.plateNumber}
        </div>
      ),
    },
    {
      key: "seats",
      header: "Seats",
      cell: (vehicle) => <div className="font-semibold text-foreground">{vehicle.seats}</div>,
    },
    {
      key: "licenseImage",
      header: "Driver License",
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
              alt="Driver License"
              thumbnailClassName="h-12 w-12 sm:h-14 sm:w-14 rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:scale-105 transition-transform"
            />
          )}
        </div>
      ),
    },
    {
      key: "vehicleLicense",
      header: "Vehicle Reg.",
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
              alt="Vehicle License"
              thumbnailClassName="h-12 w-12 sm:h-14 sm:w-14 rounded-lg shadow-sm border border-border/50 object-cover cursor-zoom-in hover:scale-105 transition-transform"
            />
          )}
        </div>
      ),
    },
    {
      key: "status",
      header: "Status",
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
      header: "Submitted",
      cell: (vehicle) => <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">{formatDate(vehicle.createdAt)}</div>,
    },
    {
      key: "actions",
      header: "Actions",
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
              <CheckCircle className="mr-1.5 h-3.5 w-3.5" />
              Verify
            </Button>
          )}
          <Button
            size="sm"
            variant={vehicle.isVerified ? "outline" : "destructive"}
            className="font-semibold text-xs shadow-sm w-fit"
            onClick={() => openConfirmDialog(vehicle, vehicle.isVerified ? "reject" : "reject")}
            disabled={verifyMutation.isPending}
          >
            <XCircle className="mr-1.5 h-3.5 w-3.5" />
            {vehicle.isVerified ? "Revoke" : "Reject"}
          </Button>
        </div>
      ),
    },
  ]

  if (error) {
    return (
      <div className="space-y-4 animate-in fade-in duration-500">
        <h1 className="text-4xl font-extrabold tracking-tight">Vehicles</h1>
        <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
          <AlertCircle className="w-6 h-6 mr-3" />
          <span className="font-semibold text-lg">Failed to load vehicles. Please try again.</span>
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
            <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">Vehicle Registration</h1>
            <p className="text-muted-foreground mt-1 text-lg font-medium">
              Review and verify driver vehicle registrations and licenses.
            </p>
          </div>
        </div>
      </div>

      <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
        <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
          <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
            <h2 className="text-xl font-bold flex items-center">
              <Car className="w-5 h-5 mr-3 text-primary" />
              Verification Queue
            </h2>
            <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
              <span className="text-muted-foreground">Total Displayed:</span> <span className="text-foreground ml-1">{data?.data?.length || 0}</span>
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
              emptyMessage="Awesome! No vehicles are currently pending verification."
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
            ? "Verify Vehicle Request"
            : confirmDialog.vehicle?.isVerified
              ? "Revoke Vehicle Verification"
              : "Reject Vehicle Request"
        }
        description={
          confirmDialog.action === "verify"
            ? "Are you sure you want to approve and verify this vehicle? The driver will be notified and can start accepting trips immediately."
            : confirmDialog.vehicle?.isVerified
              ? "Are you sure you want to revoke the verification for this vehicle? The driver will not be able to use this vehicle for trips until it is verified again."
              : "Are you sure you want to reject this vehicle submission? The driver will be notified and can resubmit their documents."
        }
        variant={confirmDialog.action === "reject" || (confirmDialog.action === "reject" && confirmDialog.vehicle?.isVerified) ? "destructive" : "default"}
        onConfirm={handleConfirmAction}
        loading={verifyMutation.isPending}
      />
    </div>
  )
}
