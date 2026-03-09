// StatCard: Reusable dashboard metric card component
// T015: Displays title, value, icon, and optional trend indicator

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { cn, formatNumber } from "@/lib/utils"
import type { LucideIcon } from "lucide-react"
import { TrendingUp, TrendingDown } from "lucide-react"

interface StatCardProps {
  title: string
  value: number
  icon: LucideIcon
  trend?: number
  trendLabel?: string
  onClick?: () => void
  className?: string
}

export function StatCard({
  title,
  value,
  icon: Icon,
  trend,
  trendLabel,
  onClick,
  className,
}: StatCardProps) {
  const isPositive = trend && trend > 0
  const isNegative = trend && trend < 0

  return (
    <Card
      className={cn(
        "transition-all duration-200",
        onClick && "cursor-pointer hover:shadow-md hover:scale-[1.02]",
        className
      )}
      onClick={onClick}
    >
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
        <Icon className="h-4 w-4 text-muted-foreground" />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{formatNumber(value)}</div>
        {trend !== undefined && (
          <div className="flex items-center text-xs text-muted-foreground mt-1">
            {isPositive && (
              <>
                <TrendingUp className="mr-1 h-3 w-3 text-green-500" />
                <span className="text-green-500">+{trend}%</span>
              </>
            )}
            {isNegative && (
              <>
                <TrendingDown className="mr-1 h-3 w-3 text-red-500" />
                <span className="text-red-500">{trend}%</span>
              </>
            )}
            {trend === 0 && <span className="text-gray-500">0%</span>}
            {trendLabel && (
              <span className="ml-1">{trendLabel}</span>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

// Stat Card Skeleton for loading state
export function StatCardSkeleton({ className }: { className?: string }) {
  return (
    <Card className={className}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <div className="h-4 w-24 animate-pulse rounded bg-muted" />
        <div className="h-4 w-4 animate-pulse rounded bg-muted" />
      </CardHeader>
      <CardContent>
        <div className="h-8 w-20 animate-pulse rounded bg-muted" />
      </CardContent>
    </Card>
  )
}
