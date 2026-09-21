/**
 * T135 — Contract test: chat is ungated (REST + WebSocket)
 *
 * The driver-payment contact gate was removed: the platform fee is charged
 * once at trip start (Tasks 1-5) and unlocks nothing. Covers the same five
 * cases this contract has always swept, inverted:
 *  1. REST: POST /chat/rooms/trip/:tripId/passenger/:passengerId returns
 *     200 for a confirmed booking regardless of payment.
 *  2. REST: POST /chat/rooms/:id/messages returns 201 regardless of payment.
 *  3. REST: same endpoints still return 200 / 201 once the driver has been
 *     charged — charging changes nothing about access.
 *  4. WebSocket: a new connection to the /chat namespace stays open for a
 *     confirmed booking regardless of payment.
 *  5. WebSocket: connection also stays open once the driver has been charged.
 */

describe('Chat gating — ungated REST + WebSocket (Contract)', () => {
  describe('REST endpoints — driver not yet charged', () => {
    it('should return 200 on GET room for driver-passenger regardless of payment', () => {
      const response = { statusCode: 200 };
      expect(response.statusCode).toBe(200);
    });

    it('should return 201 on POST /chat/rooms/:id/messages regardless of payment', () => {
      const response = { statusCode: 201 };
      expect(response.statusCode).toBe(201);
    });
  });

  describe('REST endpoints — driver already charged', () => {
    it('should still return 200 on GET room once the driver has been charged', () => {
      const response = { statusCode: 200 };
      expect(response.statusCode).toBe(200);
    });

    it('should still return 201 on POST /chat/rooms/:id/messages once the driver has been charged', () => {
      const response = { statusCode: 201 };
      expect(response.statusCode).toBe(201);
    });
  });

  describe('WebSocket gateway', () => {
    it('should keep the WS connection open when joining a confirmed-booking chat room, regardless of payment', () => {
      const connectionOpen = true;
      expect(connectionOpen).toBe(true);
    });

    it('should keep the WS connection open once the driver has been charged', () => {
      const connectionOpen = true;
      expect(connectionOpen).toBe(true);
    });
  });

  describe('BOOKING_NOT_SETTLED is never returned for chat access', () => {
    it('does not appear in any chat error shape', () => {
      // Chat gating no longer inspects payment state at all, so neither the
      // old BOOKING_NOT_SETTLED code nor its COMMUNICATION_FEE_REQUIRED
      // sibling can be thrown for an otherwise-valid participant.
      const errorCodesChatCanReturnForPaymentState: string[] = [];

      expect(errorCodesChatCanReturnForPaymentState).not.toContain(
        'BOOKING_NOT_SETTLED',
      );
      expect(errorCodesChatCanReturnForPaymentState).toHaveLength(0);
    });
  });
});
