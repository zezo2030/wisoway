// StatusBadge: Color-coded status badge component
// T019: Renders color-coded badges for different status types

import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"

type StatusVariant = "default" | "secondary" | "destructive" | "outline"
type StatusType = "user" | "payment" | "trip" | "booking" | "vehicle"

interface StatusBadgeProps {
  status: string
  type: StatusType
  className?: string
}

// Status color mappings
const statusColorMap: Record<StatusType, Record<string, StatusVariant>> = {
  user: {
    active: "default",
    banned: "destructive",
    passenger: "secondary",
    driver: "default",
    admin: "default",
  },
  payment: {
    pending: "secondary",
    approved: "default",
    rejected: "destructive",
    refunded: "outline",
  },
  trip: {
    active: "default",
    hidden: "secondary",
    completed: "default",
    cancelled: "destructive",
    expired: "outline",
  },
  booking: {
    pending: "secondary",
    confirmed: "default",
    cancelled: "destructive",
    completed: "default",
  },
  vehicle: {
    verified: "default",
    unverified: "secondary",
  },
}

// Label mappings for display
const statusLabelMap: Record<string, string> = {
  // User statuses
  active: "Active",
  banned: "Banned",
  passenger: "Passenger",
  driver: "Driver",
  admin: "Admin",
  // Payment statuses
  pending: "Pending",
  approved: "Approved",
  rejected: "Rejected",
  refunded: "Refunded",
  // Trip statuses
  hidden: "Hidden",
  completed: "Completed",
  cancelled: "Cancelled",
  expired: "Expired",
  // Booking statuses
  confirmed: "Confirmed",
  // Vehicle statuses
  verified: "Verified",
  unverified: "Unverified",
}

export function StatusBadge({ status, type, className }: StatusBadgeProps) {
  const variant = statusColorMap[type][status.toLowerCase()] || "secondary"
  const label = statusLabelMap[status.toLowerCase()] || status

  return (
    <Badge variant={variant} className={cn("capitalize", className)}>
      {label}
    </Badge>
  )
}

// Simple status badge without type (just shows the status)
interface SimpleStatusBadgeProps {
  status: string
  variant?: StatusVariant
  className?: string
}

export function SimpleStatusBadge({
  status,
  variant = "secondary",
  className,
}: SimpleStatusBadgeProps) {
  const label = statusLabelMap[status.toLowerCase()] || status

  return (
    <Badge variant={variant} className={cn("capitalize", className)}>
      {label}
    </Badge>
  )
}

export default StatusBadge
