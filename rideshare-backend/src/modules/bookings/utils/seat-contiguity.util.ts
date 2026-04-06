/** Seat layout helpers aligned with Flutter `SeatLayoutHelpers` / trip seat generation. */

export function rowSeatCounts(layout: {
  rows?: number;
  seatsPerRow?: number;
  seatsPerRowList?: number[];
} | null): number[] {
  if (!layout) {
    return [4];
  }
  const list = layout.seatsPerRowList;
  if (Array.isArray(list) && list.length > 0) {
    return list.map((n) => Number(n));
  }
  const rows = Number(layout.rows) > 0 ? Number(layout.rows) : 1;
  const spr =
    Number(layout.seatsPerRow) > 0 ? Number(layout.seatsPerRow) : 4;
  return Array.from({ length: rows }, () => spr);
}

function parseSeatId(id: string): { row: number; col: number } | null {
  const parts = id.trim().split('-');
  if (parts.length !== 2) return null;
  const row = parseInt(parts[0], 10);
  const col = parseInt(parts[1], 10);
  if (Number.isNaN(row) || Number.isNaN(col)) return null;
  return { row, col };
}

function key(r: number, c: number): string {
  return `${r},${c}`;
}

/**
 * True if all seats form one connected group via left/right/front/back adjacency
 * (same rules as passenger seat validation).
 */
export function areSeatsContiguousBlock(
  seatIds: string[],
  seatLayout: {
    rows?: number;
    seatsPerRow?: number;
    seatsPerRowList?: number[];
  } | null,
): boolean {
  if (seatIds.length <= 1) {
    return true;
  }
  const configs = rowSeatCounts(seatLayout);
  const coords = seatIds.map(parseSeatId);
  if (coords.some((c) => c === null)) {
    return false;
  }
  const parsed = coords as { row: number; col: number }[];
  const set = new Set(parsed.map((c) => key(c.row, c.col)));
  if (set.size !== parsed.length) {
    return false;
  }

  const neighbors = (row: number, col: number) => {
    const out: { row: number; col: number }[] = [];
    if (col > 0) {
      out.push({ row, col: col - 1 });
    }
    if (col < configs[row] - 1) {
      out.push({ row, col: col + 1 });
    }
    if (row > 0) {
      const prevCount = configs[row - 1];
      if (col < prevCount) {
        out.push({ row: row - 1, col });
      }
    }
    if (row < configs.length - 1) {
      const nextCount = configs[row + 1];
      if (col < nextCount) {
        out.push({ row: row + 1, col });
      }
    }
    return out;
  };

  const start = parsed[0];
  const visited = new Set<string>();
  const stack: { row: number; col: number }[] = [start];
  visited.add(key(start.row, start.col));

  while (stack.length > 0) {
    const cur = stack.pop()!;
    for (const n of neighbors(cur.row, cur.col)) {
      const k = key(n.row, n.col);
      if (!set.has(k) || visited.has(k)) {
        continue;
      }
      visited.add(k);
      stack.push(n);
    }
  }

  return visited.size === set.size;
}
