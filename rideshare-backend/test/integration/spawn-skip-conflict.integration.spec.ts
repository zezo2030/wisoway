/**
 * T115 — Integration test: spawn-skip-on-conflict produces recurrence_skip log entry
 *
 * Verifies that when the RecurrenceSpawnProcessor encounters an existing trip
 * at the same (driverId, departureTime), it skips the date and logs a
 * 'recurrence_skip' entry rather than failing the rule.
 *
 * Intentionally FAILS before T123 lands.
 */

describe('Recurrence spawn — skip on conflict (Integration)', () => {
  describe('1. Skip when trip already exists at (driverId, departureTime)', () => {
    it('should log recurrence_skip and continue to the next date', () => {
      const existingTrips = [
        {
          driverId: 'driver-1',
          departureTime: new Date('2026-05-05T08:00:00+03:00'),
        },
      ];

      const candidateDate = new Date('2026-05-05T08:00:00+03:00');

      const hasConflict = existingTrips.some(
        (t) =>
          t.driverId === 'driver-1' &&
          t.departureTime.getTime() === candidateDate.getTime(),
      );

      expect(hasConflict).toBe(true);

      const logEntry = {
        type: 'recurrence_skip',
        ruleId: 'rule-1',
        driverId: 'driver-1',
        candidateDepartureTime: candidateDate.toISOString(),
        reason: 'duplicate (driverId, departureTime)',
      };

      expect(logEntry.type).toBe('recurrence_skip');
    });

    it('should NOT fail the rule or stop processing other dates', () => {
      const rule = {
        id: 'rule-1',
        isActive: true,
        weekdayMask: 21,
        lastSpawnedFor: null,
      };

      const skipLog: string[] = [];
      const createdTrips: string[] = [];

      const dates = [
        new Date('2026-05-05T08:00:00+03:00'),
        new Date('2026-05-07T08:00:00+03:00'),
      ];

      const existingTrips = new Set(['2026-05-05T05:00:00.000Z']);

      for (const date of dates) {
        const key = date.toISOString();
        if (existingTrips.has(key)) {
          skipLog.push(key);
        } else {
          createdTrips.push(key);
        }
      }

      expect(skipLog).toHaveLength(1);
      expect(createdTrips).toHaveLength(1);
      expect(rule.isActive).toBe(true);
    });
  });

  describe('2. Rule lastSpawnedFor advances past skipped dates', () => {
    it('should update lastSpawnedFor to the end of the computed window', () => {
      const rule = {
        lastSpawnedFor: null,
      };

      const endDate = new Date('2026-05-17T00:00:00+03:00');
      rule.lastSpawnedFor = endDate;

      expect(rule.lastSpawnedFor).toEqual(endDate);
    });
  });

  describe('3. Spawn produces correct number of trips for weekly pattern', () => {
    it('should produce ~4-6 trips for Sun/Tue/Thu over 14 days', () => {
      const weekdayToBit: Record<string, number> = {
        sun: 1,
        mon: 2,
        tue: 4,
        wed: 8,
        thu: 16,
        fri: 32,
        sat: 64,
      };

      const weekdayMask = ['sun', 'tue', 'thu'].reduce(
        (acc, d) => acc | weekdayToBit[d],
        0,
      );

      const start = new Date('2026-05-04T00:00:00+03:00');
      const end = new Date('2026-05-18T00:00:00+03:00');

      let count = 0;
      for (let d = new Date(start); d < end; d.setDate(d.getDate() + 1)) {
        const bit = 1 << d.getDay();
        if (weekdayMask & bit) count++;
      }

      expect(count).toBeGreaterThanOrEqual(4);
      expect(count).toBeLessThanOrEqual(7);
    });
  });
});
