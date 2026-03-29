import type { SeatLayout } from "@/types/models"
import { backendSeatIdToDisplayIndex } from "@/lib/seat-layout"

type LayoutArg = Pick<SeatLayout, "rows" | "seatsPerRow" | "seatsPerRowList"> | undefined

/**
 * Backend stores seats as "row-col" (0-based). Dashboard & mobile show linear 1-based index.
 * Pass full seatLayout for mixed (seatsPerRowList) trips; or legacy seatsPerRow number only.
 */
export function formatSeatDisplay(
  raw: string | undefined,
  layoutOrSeatsPerRow?: LayoutArg | number
): string {
  if (raw == null || raw === "") return "—"
  const s = String(raw).trim()
  const m = /^(\d+)-(\d+)$/.exec(s)
  if (!m) return s

  if (typeof layoutOrSeatsPerRow === "number") {
    const seatsPerRow = layoutOrSeatsPerRow
    if (seatsPerRow > 0) {
      const row = parseInt(m[1], 10)
      const col = parseInt(m[2], 10)
      return String(row * seatsPerRow + col + 1)
    }
    return s
  }

  if (layoutOrSeatsPerRow && typeof layoutOrSeatsPerRow === "object") {
    const idx = backendSeatIdToDisplayIndex(layoutOrSeatsPerRow, s)
    if (idx != null) return String(idx)
  }

  return s
}
