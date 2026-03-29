import type { SeatLayout } from "@/types/models"

export type SeatLayoutLike = Pick<SeatLayout, "rows" | "seatsPerRow" | "seatsPerRowList">

/** Seats per visual row: custom list or uniform rows × seatsPerRow (matches app + API order). */
export function rowSeatCounts(layout: SeatLayoutLike): number[] {
  const list = layout.seatsPerRowList
  if (Array.isArray(list) && list.length > 0) {
    return list.map((n) => Math.max(0, Math.floor(Number(n))))
  }
  const rows = Math.max(0, Math.floor(layout.rows ?? 0))
  const spr = Math.max(0, Math.floor(layout.seatsPerRow ?? 0))
  return Array.from({ length: rows }, () => spr)
}

export function backendCoordsToDisplayIndex(
  layout: SeatLayoutLike,
  row: number,
  col: number
): number | null {
  const configs = rowSeatCounts(layout)
  if (row < 0 || row >= configs.length) return null
  if (col < 0 || col >= configs[row]) return null
  let sum = 0
  for (let i = 0; i < row; i++) sum += configs[i]
  return sum + col + 1
}

export function displayIndexToBackendId(layout: SeatLayoutLike, oneBased: number): string | null {
  if (oneBased < 1) return null
  const configs = rowSeatCounts(layout)
  let remaining = oneBased - 1
  for (let r = 0; r < configs.length; r++) {
    const count = configs[r]
    if (remaining < count) return `${r}-${remaining}`
    remaining -= count
  }
  return null
}

export function backendSeatIdToDisplayIndex(layout: SeatLayoutLike, raw: string): number | null {
  const m = /^(\d+)-(\d+)$/.exec(String(raw).trim())
  if (!m) return null
  return backendCoordsToDisplayIndex(layout, parseInt(m[1], 10), parseInt(m[2], 10))
}

export function layoutSummaryText(layout: SeatLayoutLike): string {
  const list = layout.seatsPerRowList
  if (Array.isArray(list) && list.length > 0) {
    return `Custom: ${list.join(" · ")}`
  }
  return `${layout.rows} × ${layout.seatsPerRow}`
}
