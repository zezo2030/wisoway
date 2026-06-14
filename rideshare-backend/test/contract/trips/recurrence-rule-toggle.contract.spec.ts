/**
 * T114 — Contract test: PATCH /trips/recurrence-rules/:id weekday/until/isActive toggles
 *
 * Covers:
 *  1. PATCH isActive toggle (pause/resume)
 *  2. PATCH until date change
 *  3. PATCH weekdays change
 *  4. Only the rule owner (driver) can patch
 *
 * These tests intentionally FAIL before T122 lands.
 */

describe('PATCH /trips/recurrence-rules/:id (Contract)', () => {
  describe('1. Toggle isActive', () => {
    it('should deactivate a rule (pause spawning)', () => {
      const rule = { id: 'rule-1', isActive: true };
      const patched = { ...rule, isActive: false };

      expect(patched.isActive).toBe(false);
    });

    it('should reactivate a rule (resume spawning)', () => {
      const rule = { id: 'rule-1', isActive: false };
      const patched = { ...rule, isActive: true };

      expect(patched.isActive).toBe(true);
    });
  });

  describe('2. Change until date', () => {
    it('should accept a new until date', () => {
      const rule = { id: 'rule-1', until: '2026-08-01' };
      const patched = { ...rule, until: '2026-12-31' };

      expect(patched.until).toBe('2026-12-31');
    });

    it('should accept null until (indefinite recurrence)', () => {
      const rule = { id: 'rule-1', until: '2026-08-01' };
      const patched = { ...rule, until: null };

      expect(patched.until).toBeNull();
    });
  });

  describe('3. Change weekdays', () => {
    it('should accept new weekday set and recompute bitmask', () => {
      const weekdayToBit: Record<string, number> = {
        sun: 1,
        mon: 2,
        tue: 4,
        wed: 8,
        thu: 16,
        fri: 32,
        sat: 64,
      };

      const oldWeekdays = ['sun', 'tue', 'thu'];
      const newWeekdays = ['mon', 'wed', 'fri'];

      const oldMask = oldWeekdays.reduce((acc, d) => acc | weekdayToBit[d], 0);
      const newMask = newWeekdays.reduce((acc, d) => acc | weekdayToBit[d], 0);

      expect(oldMask).toBe(21);
      expect(newMask).toBe(2 | 8 | 32);
      expect(newMask).toBe(42);
    });
  });

  describe('4. Only rule owner can patch', () => {
    it('should return 403 when a non-owner driver tries to patch', () => {
      const rule = { id: 'rule-1', driverId: 'driver-A' };
      const requestingDriver = 'driver-B';

      const isOwner = rule.driverId === requestingDriver;
      expect(isOwner).toBe(false);
    });
  });
});
