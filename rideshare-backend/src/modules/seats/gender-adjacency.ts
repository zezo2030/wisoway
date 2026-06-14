/**
 * Gender-adjacency helper
 *
 * Determines whether a proposed set of seat assignments would violate the
 * gender-adjacency rule: a female passenger cannot be assigned a seat
 * horizontally adjacent to a male passenger (and vice-versa), unless the
 * adjacent seat is within the same companion group being booked together.
 *
 * The rule is applied against the FULL prospective seat set:
 *   - All already-booked seats on the trip (with their stored gender)
 *   - All seats being proposed in this booking request
 *
 * Phase 4 / T067 — 008-platform-completion, US2 / 010-booking-lifecycle.
 */

export type SeatGender = 'male' | 'female';

export interface ExistingSeat {
  seatNumber: string;
  gender: SeatGender | null;
  status: 'available' | 'booked' | string;
}

export interface ProposedSeat {
  seatNumber: string;
  gender: SeatGender;
}

/**
 * Returns true when any horizontally adjacent pair in the merged seat set
 * has a gender mismatch.
 *
 * Seat number format: "rowIndex-colIndex" (e.g. "0-0", "1-2").
 * Only horizontal adjacency (same row, consecutive columns) is checked.
 *
 * @param existingSeats  All seat rows already on the trip (from trip.seats JSON).
 * @param proposedSeats  The new seats being requested in this booking.
 */
export function hasGenderAdjacencyViolation(
  existingSeats: ExistingSeat[],
  proposedSeats: ProposedSeat[],
): boolean {
  // Build a map: rowIndex → Map<colIndex, gender>
  type RowMap = Map<number, SeatGender>;
  const rows = new Map<number, RowMap>();

  const addEntry = (seatNumber: string, gender: SeatGender | null) => {
    if (!gender) return;
    const parts = seatNumber.split('-');
    if (parts.length < 2) return;
    const r = parseInt(parts[0], 10);
    const c = parseInt(parts[1], 10);
    if (Number.isNaN(r) || Number.isNaN(c)) return;
    if (!rows.has(r)) rows.set(r, new Map());
    rows.get(r)!.set(c, gender);
  };

  // 1. Insert already-booked existing seats
  for (const seat of existingSeats) {
    if (seat.status === 'booked' && seat.gender) {
      addEntry(seat.seatNumber, seat.gender);
    }
  }

  // 2. Insert proposed seats (overwrite if same index — proposed gender wins)
  for (const seat of proposedSeats) {
    addEntry(seat.seatNumber, seat.gender);
  }

  // 3. Check each row for horizontal adjacency conflicts
  for (const [, colMap] of rows) {
    const cols = Array.from(colMap.keys()).sort((a, b) => a - b);
    for (let i = 0; i < cols.length - 1; i++) {
      if (cols[i + 1] === cols[i] + 1) {
        // Adjacent columns
        const leftGender = colMap.get(cols[i])!;
        const rightGender = colMap.get(cols[i + 1])!;
        if (leftGender !== rightGender) {
          return true; // violation found
        }
      }
    }
  }

  return false;
}

/**
 * Find all valid starting positions for a group of `count` seats in a single
 * row that do not violate gender-adjacency constraints.
 *
 * Returns an array of [rowIndex, firstColIndex] pairs where a contiguous run
 * of `count` seats can be placed without creating a mixed-gender adjacency.
 *
 * Used by the auto-pick algorithm (T066).
 */
export function findValidStartPositions(
  existingSeats: ExistingSeat[],
  proposedGenders: SeatGender[],
  seatLayout: {
    rows: number;
    seatsPerRow?: number;
    seatsPerRowList?: number[];
  },
): Array<{ row: number; startCol: number }> {
  const count = proposedGenders.length;
  const results: Array<{ row: number; startCol: number }> = [];

  const getRowSize = (r: number): number => {
    if (Array.isArray(seatLayout.seatsPerRowList)) {
      return seatLayout.seatsPerRowList[r] ?? 0;
    }
    return seatLayout.seatsPerRow ?? 0;
  };

  for (let r = 0; r < seatLayout.rows; r++) {
    const rowSize = getRowSize(r);
    if (rowSize < count) continue;

    for (let startCol = 0; startCol <= rowSize - count; startCol++) {
      // Check that all target seats are available
      const allAvailable = proposedGenders.every((_, offset) => {
        const seatNum = `${r}-${startCol + offset}`;
        const existing = existingSeats.find((s) => s.seatNumber === seatNum);
        return !existing || existing.status === 'available';
      });

      if (!allAvailable) continue;

      // Build proposed seat set for this candidate position
      const proposed: ProposedSeat[] = proposedGenders.map(
        (gender, offset) => ({
          seatNumber: `${r}-${startCol + offset}`,
          gender,
        }),
      );

      if (!hasGenderAdjacencyViolation(existingSeats, proposed)) {
        results.push({ row: r, startCol });
      }
    }
  }

  return results;
}
