// SeatMap: Visual seat layout grid component
// T030: Renders seat layout with color-coded status

import type { ReactNode } from "react"
import { cn } from "@/lib/utils"
import { rowSeatCounts } from "@/lib/seat-layout"
import type { Seat, SeatLayout } from "@/types/models"
import { SeatStatus, Gender } from "@/types/enums"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"

interface SeatMapProps {
  seatLayout: SeatLayout
  seats: Seat[]
  preventGenderMixing?: boolean
  className?: string
}

export function SeatMap({ seatLayout, seats, preventGenderMixing = false, className }: SeatMapProps) {
  const normalizedSeats = Array.isArray(seats) ? seats : []
  const rowWidths = rowSeatCounts(seatLayout)

  // Create a map of linear 1-based seat index to seat data (matches getTripSeats normalization)
  const seatMap = new Map(normalizedSeats.map((seat) => [seat.seatNumber, seat]))

  // Get seat status color
  const getSeatColor = (seat: Seat | undefined) => {
    if (!seat) return "bg-gray-200" // Unknown seat

    switch (seat.status) {
      case SeatStatus.AVAILABLE:
        return "bg-green-500 hover:bg-green-600"
      case SeatStatus.BOOKED:
        return "bg-blue-500 hover:bg-blue-600"
      case SeatStatus.LOCKED:
        return "bg-orange-500 hover:bg-orange-600"
      default:
        return "bg-gray-200"
    }
  }

  // Get seat tooltip content
  const getSeatTooltip = (seat: Seat | undefined, seatNumber: number) => {
    if (!seat) return `Seat ${seatNumber}: Unknown`

    let tooltip = `Seat ${seatNumber}: ${seat.status}`

    if (seat.status === SeatStatus.BOOKED && seat.passengerGender) {
      tooltip += ` (${seat.passengerGender})`
    }

    return tooltip
  }

  // Get gender indicator
  const getGenderIndicator = (seat: Seat | undefined) => {
    if (!seat || !preventGenderMixing || seat.status !== SeatStatus.BOOKED) return null

    return seat.passengerGender === Gender.MALE ? (
      <span className="text-[10px] text-white font-bold">M</span>
    ) : seat.passengerGender === Gender.FEMALE ? (
      <span className="text-[10px] text-white font-bold">F</span>
    ) : null
  }

  // Generate seat grid (matches Flutter SeatLayoutWidget: row-major order, no aisle gap).
  // App uses RTL for Arabic: first column (seat 1) is on the visual right — mirror via dir="rtl".
  const generateSeats = () => {
    const grid: ReactNode[] = []
    let displayIndex = 0

    for (let row = 0; row < rowWidths.length; row++) {
      const cols = rowWidths[row]
      const rowSeats: ReactNode[] = []
      for (let col = 0; col < cols; col++) {
        displayIndex++
        const seat = seatMap.get(displayIndex)

        rowSeats.push(
          <Tooltip key={`${row}-${col}-${displayIndex}`}>
            <TooltipTrigger asChild>
              <div
                className={cn(
                  "w-10 h-10 rounded-md flex flex-col items-center justify-center cursor-pointer transition-colors gap-0.5",
                  getSeatColor(seat),
                  seat ? "text-white" : "text-gray-700 text-[10px] font-bold"
                )}
              >
                {getGenderIndicator(seat)}
                <span className="text-[9px] font-bold tabular-nums leading-none opacity-95">{displayIndex}</span>
              </div>
            </TooltipTrigger>
            <TooltipContent>
              <p>{getSeatTooltip(seat, displayIndex)}</p>
            </TooltipContent>
          </Tooltip>
        )
      }
      grid.push(
        <div key={row} className="flex flex-row items-center justify-center gap-2">
          {rowSeats}
        </div>
      )
    }

    return grid
  }

  return (
    <TooltipProvider>
      <div className={cn("space-y-4", className)}>
        <div className="flex flex-col gap-2" dir="rtl">
          {generateSeats()}
        </div>

        {/* Legend */}
        <div className="flex flex-wrap gap-4 justify-center text-sm">
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-green-500" />
            <span>Available</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-blue-500" />
            <span>Booked</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-4 h-4 rounded bg-orange-500" />
            <span>Locked</span>
          </div>
          {preventGenderMixing && (
            <>
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 rounded bg-blue-500 flex items-center justify-center">
                  <span className="text-[8px] text-white font-bold">M</span>
                </div>
                <span>Male</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 rounded bg-blue-500 flex items-center justify-center">
                  <span className="text-[8px] text-white font-bold">F</span>
                </div>
                <span>Female</span>
              </div>
            </>
          )}
        </div>
      </div>
    </TooltipProvider>
  )
}

export default SeatMap
