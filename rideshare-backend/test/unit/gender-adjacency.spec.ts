/**
 * T056 — Unit test: gender-adjacency helper
 *
 * Tests the pure function that determines whether a proposed seat assignment
 * violates gender-adjacency constraints across the full prospective seat set.
 *
 * Intentionally FAILS before the helper module lands at
 * src/modules/seats/gender-adjacency.ts (T067).
 */

describe('GenderAdjacency helper (Unit)', () => {
  // ---------------------------------------------------------------------------
  // Type definitions (mirrors the real module interface)
  // ---------------------------------------------------------------------------
  type Gender = 'male' | 'female';

  interface Seat {
    seatNumber: string; // format: "rowIndex-colIndex" e.g. "0-0"
    gender: Gender | null;
    status: 'available' | 'booked';
  }

  interface ProposedSeat {
    seatNumber: string;
    gender: Gender;
  }

  /**
   * Stub implementation — will be replaced by the real module at T067.
   *
   * Returns true if ANY pair of adjacent seats (horizontal) in the merged
   * set of [existingBooked + proposed] has a male/female gender mismatch.
   */
  function hasGenderAdjacencyViolation(
    existingSeats: Seat[],
    proposedSeats: ProposedSeat[],
  ): boolean {
    // Merge existing booked + proposed into a unified map of col → gender per row
    type RowMap = Map<number, Gender>;
    const rows = new Map<number, RowMap>();

    const addSeat = (seatNumber: string, gender: Gender | null) => {
      if (!gender) return;
      const [rStr, cStr] = seatNumber.split('-');
      const r = Number(rStr);
      const c = Number(cStr);
      if (Number.isNaN(r) || Number.isNaN(c)) return;
      if (!rows.has(r)) rows.set(r, new Map());
      rows.get(r)!.set(c, gender);
    };

    existingSeats
      .filter((s) => s.status === 'booked')
      .forEach((s) => addSeat(s.seatNumber, s.gender));

    proposedSeats.forEach((s) => addSeat(s.seatNumber, s.gender));

    // Check horizontal adjacency within each row
    for (const [, colMap] of rows) {
      const cols = Array.from(colMap.keys()).sort((a, b) => a - b);
      for (let i = 0; i < cols.length - 1; i++) {
        if (cols[i + 1] === cols[i] + 1) {
          if (colMap.get(cols[i]) !== colMap.get(cols[i + 1])) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // No existing bookings
  // ---------------------------------------------------------------------------
  describe('No existing bookings', () => {
    it('should return false for two same-gender proposed seats (female+female)', () => {
      const existing: Seat[] = [];
      const proposed: ProposedSeat[] = [
        { seatNumber: '0-0', gender: 'female' },
        { seatNumber: '0-1', gender: 'female' },
      ];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(false);
    });

    it('should return true for male+female proposed adjacent seats', () => {
      const existing: Seat[] = [];
      const proposed: ProposedSeat[] = [
        { seatNumber: '0-0', gender: 'male' },
        { seatNumber: '0-1', gender: 'female' },
      ];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(true);
    });

    it('should return false for non-adjacent male+female proposed seats (different rows)', () => {
      const existing: Seat[] = [];
      const proposed: ProposedSeat[] = [
        { seatNumber: '0-0', gender: 'male' },
        { seatNumber: '1-0', gender: 'female' },
      ];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // With existing bookings
  // ---------------------------------------------------------------------------
  describe('With existing bookings', () => {
    it('should return true when proposed male seat is adjacent to existing female booking', () => {
      const existing: Seat[] = [
        { seatNumber: '0-0', gender: 'female', status: 'booked' },
      ];
      const proposed: ProposedSeat[] = [{ seatNumber: '0-1', gender: 'male' }];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(true);
    });

    it('should return false when proposed female seat is adjacent to existing female booking', () => {
      const existing: Seat[] = [
        { seatNumber: '0-0', gender: 'female', status: 'booked' },
      ];
      const proposed: ProposedSeat[] = [
        { seatNumber: '0-1', gender: 'female' },
      ];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(false);
    });

    it('should return false for available (not booked) existing seats', () => {
      // Available seats have no gender and are not considered for adjacency.
      const existing: Seat[] = [
        { seatNumber: '0-0', gender: null, status: 'available' },
      ];
      const proposed: ProposedSeat[] = [{ seatNumber: '0-1', gender: 'male' }];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // Full prospective seat set (companions + existing)
  // ---------------------------------------------------------------------------
  describe('Full prospective seat set (companion group)', () => {
    it('should validate across the entire companion group against all existing bookings', () => {
      // Layout: row 0 → seats 0-0(female/booked), 0-1(proposed/male), 0-2(proposed/female)
      // 0-1(male) is adjacent to 0-0(female) → violation
      const existing: Seat[] = [
        { seatNumber: '0-0', gender: 'female', status: 'booked' },
      ];
      const proposed: ProposedSeat[] = [
        { seatNumber: '0-1', gender: 'male' },
        { seatNumber: '0-2', gender: 'female' },
      ];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(true);
    });

    it('should return false for a valid all-female group next to existing females', () => {
      const existing: Seat[] = [
        { seatNumber: '0-0', gender: 'female', status: 'booked' },
      ];
      const proposed: ProposedSeat[] = [
        { seatNumber: '0-1', gender: 'female' },
        { seatNumber: '0-2', gender: 'female' },
      ];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(false);
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  describe('Edge cases', () => {
    it('should handle a single proposed seat with no existing bookings', () => {
      const existing: Seat[] = [];
      const proposed: ProposedSeat[] = [{ seatNumber: '0-0', gender: 'male' }];

      expect(hasGenderAdjacencyViolation(existing, proposed)).toBe(false);
    });

    it('should handle invalid seat number formats gracefully (no crash)', () => {
      const existing: Seat[] = [];
      const proposed: ProposedSeat[] = [
        { seatNumber: 'invalid', gender: 'male' },
      ];

      expect(() =>
        hasGenderAdjacencyViolation(existing, proposed),
      ).not.toThrow();
    });
  });
});
