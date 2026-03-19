/**
 * Backend stores seats as "row-col" (0-based). Mobile & seat map use linear 1-based index.
 */
export function formatSeatDisplay(raw: string | undefined, seatsPerRow?: number): string {
  if (raw == null || raw === "") return "—"
  const s = String(raw).trim()
  const m = /^(\d+)-(\d+)$/.exec(s)
  if (m && seatsPerRow != null && seatsPerRow > 0) {
    const row = parseInt(m[1], 10)
    const col = parseInt(m[2], 10)
    return String(row * seatsPerRow + col + 1)
  }
  return s
}
