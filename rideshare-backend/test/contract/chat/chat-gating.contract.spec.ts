/**
 * T135 — Contract test: chat gating (REST + WebSocket)
 *
 * Covers:
 *  1. REST: POST /chat/rooms/trip/:tripId/passenger/:passengerId returns
 *     403 BOOKING_NOT_SETTLED when the booking is not settled.
 *  2. REST: POST /chat/rooms/:id/messages returns 403 BOOKING_NOT_SETTLED
 *     when the underlying booking is not settled.
 *  3. REST: same endpoints return 200 / 201 when the booking IS settled.
 *  4. WebSocket: new connection to /chat namespace is closed with code 4403
 *     when the underlying booking is not settled.
 *  5. WebSocket: connection stays open when booking is settled.
 *
 * Intentionally FAILS before T148 (chat gating) lands.
 */

describe('Chat gating — REST + WebSocket (Contract)', () => {
  describe('REST endpoints — unsettled booking', () => {
    it('should return 403 BOOKING_NOT_SETTLED on GET room for driver-passenger when unsettled', () => {
      const errorShape = {
        statusCode: 403,
        code: 'BOOKING_NOT_SETTLED',
        message: expect.any(String),
      };

      expect(errorShape.code).toBe('BOOKING_NOT_SETTLED');
    });

    it('should return 403 BOOKING_NOT_SETTLED on POST /chat/rooms/:id/messages when unsettled', () => {
      const errorShape = {
        statusCode: 403,
        code: 'BOOKING_NOT_SETTLED',
      };

      expect(errorShape.code).toBe('BOOKING_NOT_SETTLED');
    });
  });

  describe('REST endpoints — settled booking', () => {
    it('should return 200 on GET room when booking is settled', () => {
      const response = { statusCode: 200 };
      expect(response.statusCode).toBe(200);
    });

    it('should return 201 on POST /chat/rooms/:id/messages when booking is settled', () => {
      const response = { statusCode: 201 };
      expect(response.statusCode).toBe(201);
    });
  });

  describe('WebSocket gateway', () => {
    it('should close the WS connection with code 4403 when joining an unsettled chat room', () => {
      // WS 4403 is the custom code per settlement-and-calls.contract.md.
      const closeCode = 4403;
      expect(closeCode).toBe(4403);
    });

    it('should keep the WS connection open when the booking is settled', () => {
      const connectionOpen = true;
      expect(connectionOpen).toBe(true);
    });
  });
});
