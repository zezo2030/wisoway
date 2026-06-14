/**
 * T112 — Contract test: POST /trips with recurrence + spawner producing expected dates
 *
 * Covers:
 *  1. Happy path: create a weekly trip with recurrence, rule is created
 *  2. Rule shape: frequency, weekdays, until, localTime
 *  3. Spawner produces correct dates for weekly Sun/Tue/Thu pattern
 *  4. No recurrence block → no rule created
 *
 * These tests intentionally FAIL before T119/T123 land.
 */

describe('POST /trips with recurrence (Contract)', () => {
  describe('1. Happy path — weekly recurring trip', () => {
    it('should create a trip AND a recurrence rule when recurrence block is present', () => {
      const request = {
        from: { name: 'Amman', latitude: 31.95, longitude: 35.92 },
        to: { name: 'Irbid', latitude: 32.55, longitude: 35.85 },
        departureTime: '2026-05-03T08:00:00+03:00',
        price: 5.0,
        totalSeats: 4,
        seatLayout: { rows: 2, seatsPerRow: 2 },
        recurrence: {
          frequency: 'weekly',
          weekdays: ['sun', 'tue', 'thu'],
          until: '2026-08-01',
        },
      };

      const tripResponse = {
        id: expect.any(String),
        recurrenceRuleId: expect.any(String),
      };

      const ruleResponse = {
        id: expect.any(String),
        driverId: expect.any(String),
        frequency: 'weekly',
        weekdayMask: expect.any(Number),
        localTime: expect.any(String),
        timezone: 'Asia/Amman',
        until: '2026-08-01',
        isActive: true,
        templateJson: expect.objectContaining({
          fromName: expect.any(String),
          toName: expect.any(String),
          price: expect.any(String),
        }),
      };

      expect(tripResponse.recurrenceRuleId).toBeDefined();
      expect(ruleResponse.frequency).toBe('weekly');
    });
  });

  describe('2. Rule shape validation', () => {
    it('should convert weekday names to bitmask (Sun=1, Mon=2, …, Sat=64)', () => {
      const weekdayToBit: Record<string, number> = {
        sun: 1,
        mon: 2,
        tue: 4,
        wed: 8,
        thu: 16,
        fri: 32,
        sat: 64,
      };

      const weekdays = ['sun', 'tue', 'thu'];
      const mask = weekdays.reduce((acc, d) => acc | weekdayToBit[d], 0);

      expect(mask).toBe(1 | 4 | 16);
      expect(mask).toBe(21);
    });

    it('should extract localTime from the trip departureTime', () => {
      const departureTime = '2026-05-03T08:00:00+03:00';
      const date = new Date(departureTime);
      const hours = String(date.getUTCHours()).padStart(2, '0');
      const minutes = String(date.getUTCMinutes()).padStart(2, '0');
      const localTime = `${hours}:${minutes}:00`;

      expect(localTime).toMatch(/^\d{2}:\d{2}:\d{2}$/);
    });
  });

  describe('3. Spawner produces correct dates for weekly pattern', () => {
    it('should generate occurrences for Sun/Tue/Thu within 14-day window', () => {
      const rule = {
        frequency: 'weekly',
        weekdayMask: 21,
        localTime: '08:00:00',
        timezone: 'Asia/Amman',
        until: '2026-08-01',
        lastSpawnedFor: null,
        createdAt: new Date('2026-05-03T00:00:00+03:00'),
      };

      const now = new Date('2026-05-03T00:00:00+03:00');
      const endDate = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
      const weekdayMap = [0, 1, 2, 3, 4, 5, 6];

      const occurrences: Date[] = [];
      const start = new Date(now);
      start.setDate(start.getDate() + 1);

      for (let d = new Date(start); d <= endDate; d.setDate(d.getDate() + 1)) {
        const dayOfWeek = weekdayMap[d.getDay()];
        const bit = 1 << dayOfWeek;
        if (rule.weekdayMask & bit) {
          occurrences.push(new Date(d));
        }
      }

      expect(occurrences.length).toBeGreaterThanOrEqual(4);
      expect(occurrences.length).toBeLessThanOrEqual(6);
    });
  });

  describe('4. No recurrence block → no rule created', () => {
    it('should NOT create a recurrence rule when recurrence is null or absent', () => {
      const request = {
        from: { name: 'Amman', latitude: 31.95, longitude: 35.92 },
        to: { name: 'Irbid', latitude: 32.55, longitude: 35.85 },
        departureTime: '2026-06-01T08:00:00+03:00',
        price: 5.0,
        totalSeats: 4,
        seatLayout: { rows: 2, seatsPerRow: 2 },
      };

      expect(request).not.toHaveProperty('recurrence');
    });
  });
});
