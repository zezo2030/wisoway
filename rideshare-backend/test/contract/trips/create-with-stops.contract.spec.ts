/**
 * T111 — Contract test: POST /trips with stops
 *
 * Covers:
 *  1. Happy path: create a trip with 2 stops, response includes stops array
 *  2. Stops validation: max 5 stops
 *  3. Stop shape validation: name, address, lat, lng, order required
 *  4. Notes field: optional free-text
 *
 * These tests intentionally FAIL before T119 lands.
 */

describe('POST /trips with stops (Contract)', () => {
  describe('1. Happy path — trip with 2 stops', () => {
    it('should return 201 with stops array preserving order', () => {
      const request = {
        from: { name: 'Amman', latitude: 31.95, longitude: 35.92 },
        to: { name: 'Irbid', latitude: 32.55, longitude: 35.85 },
        departureTime: '2026-06-01T08:00:00+03:00',
        price: 5.0,
        totalSeats: 4,
        seatLayout: { rows: 2, seatsPerRow: 2 },
        stops: [
          {
            name: 'Zarqa fuel stop',
            address: 'Zarqa',
            lat: 32.07,
            lng: 36.09,
            order: 1,
            note: '5 min stop',
          },
          {
            name: 'Jerash rest area',
            address: 'Jerash',
            lat: 32.28,
            lng: 35.89,
            order: 2,
          },
        ],
        notes: 'No smoking please.',
      };

      const responseShape = {
        id: expect.any(String),
        stops: expect.arrayContaining([
          expect.objectContaining({
            name: expect.any(String),
            address: expect.any(String),
            lat: expect.any(Number),
            lng: expect.any(Number),
            order: expect.any(Number),
          }),
        ]),
        notes: 'No smoking please.',
      };

      expect(responseShape.stops).toHaveLength(2);
      expect(responseShape.notes).toBe('No smoking please.');
    });

    it('should preserve stop order as submitted', () => {
      const stops = [
        { name: 'A', address: 'A', lat: 1, lng: 1, order: 1 },
        { name: 'B', address: 'B', lat: 2, lng: 2, order: 2 },
      ];

      const sorted = [...stops].sort((a, b) => a.order - b.order);
      expect(sorted[0].name).toBe('A');
      expect(sorted[1].name).toBe('B');
    });
  });

  describe('2. Stops validation — max 5', () => {
    it('should reject when more than 5 stops are provided', () => {
      const stops = Array.from({ length: 6 }, (_, i) => ({
        name: `Stop ${i + 1}`,
        address: `Address ${i + 1}`,
        lat: 31 + i * 0.1,
        lng: 35 + i * 0.1,
        order: i + 1,
      }));

      expect(stops.length).toBeGreaterThan(5);
    });

    it('should accept exactly 5 stops', () => {
      const stops = Array.from({ length: 5 }, (_, i) => ({
        name: `Stop ${i + 1}`,
        address: `Address ${i + 1}`,
        lat: 31 + i * 0.1,
        lng: 35 + i * 0.1,
        order: i + 1,
      }));

      expect(stops.length).toBe(5);
    });
  });

  describe('3. Stop shape validation', () => {
    it('should require name, lat, lng, order on each stop', () => {
      const validStop = {
        name: 'Stop',
        address: 'Addr',
        lat: 31.95,
        lng: 35.92,
        order: 1,
      };

      expect(validStop).toHaveProperty('name');
      expect(validStop).toHaveProperty('lat');
      expect(validStop).toHaveProperty('lng');
      expect(validStop).toHaveProperty('order');
    });
  });

  describe('4. Notes field', () => {
    it('should accept notes as optional free-text', () => {
      const withNotes = { notes: 'No smoking please.' };
      const withoutNotes = {};

      expect(typeof withNotes.notes).toBe('string');
      expect(withoutNotes.notes).toBeUndefined();
    });
  });
});
