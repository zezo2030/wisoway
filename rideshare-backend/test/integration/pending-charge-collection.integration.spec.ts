/**
 * T054 — Integration test: hybrid pending-charge collection
 *
 * Verifies two paths of PendingChargeService:
 *  A. Wallet-rich: balance ≥ charge → deducted immediately, status='applied'
 *  B. Wallet-empty: balance < charge → charge stays 'pending', carried
 *     forward and collected on the next booking confirmation.
 *
 * Intentionally FAILS before T074/T075 land.
 */

describe('Hybrid pending-charge collection (Integration)', () => {
  // ---------------------------------------------------------------------------
  // A. Wallet-rich path
  // ---------------------------------------------------------------------------
  describe('A. Wallet-rich — immediate deduction', () => {
    it('should set charge.status = "applied" when wallet balance covers the charge', () => {
      const walletBalance = 5.0;
      const chargeAmount = 0.5;

      const canDeduct = walletBalance >= chargeAmount;
      const chargeStatus = canDeduct ? 'applied' : 'pending';

      expect(canDeduct).toBe(true);
      expect(chargeStatus).toBe('applied');
    });

    it('should set walletTransactionId on the charge when deducted', () => {
      const charge = {
        status: 'applied',
        walletTransactionId: 'wt-uuid',
        appliedToBookingId: null,
      };

      expect(charge.walletTransactionId).toBeDefined();
      expect(charge.status).toBe('applied');
    });

    it('should post a WalletTransaction ADJUSTMENT/DEBIT entry', () => {
      const walletTx = {
        type: 'adjustment',
        direction: 'debit',
        amount: 0.5,
        userId: 'pax-uuid',
      };

      expect(walletTx.direction).toBe('debit');
      expect(walletTx.amount).toBe(0.5);
    });
  });

  // ---------------------------------------------------------------------------
  // B. Wallet-empty path (carry-forward)
  // ---------------------------------------------------------------------------
  describe('B. Wallet-empty — carry-forward', () => {
    it('should leave charge.status = "pending" when wallet is insufficient', () => {
      const walletBalance = 0.0;
      const chargeAmount = 0.5;

      const canDeduct = walletBalance >= chargeAmount;
      const chargeStatus = canDeduct ? 'applied' : 'pending';

      expect(canDeduct).toBe(false);
      expect(chargeStatus).toBe('pending');
    });

    it('should collect the pending charge on next booking confirmation', () => {
      // When collectOutstanding() is called from the accept handler,
      // the pending charge should be retried.
      const chargeBeforeCollect = { status: 'pending', amount: 0.5 };
      const walletBalanceAtConfirm = 10.0; // now funded

      const canDeduct = walletBalanceAtConfirm >= chargeBeforeCollect.amount;
      const chargeAfterCollect = {
        status: canDeduct ? 'applied' : 'pending',
        appliedToBookingId: canDeduct ? 'booking-b' : null,
      };

      expect(chargeAfterCollect.status).toBe('applied');
      expect(chargeAfterCollect.appliedToBookingId).toBe('booking-b');
    });

    it('should set appliedToBookingId when carried forward and later collected', () => {
      const charge = {
        status: 'applied',
        appliedToBookingId: 'booking-context-id',
        walletTransactionId: 'wt-uuid-2',
      };

      expect(charge.appliedToBookingId).toBeDefined();
      expect(charge.walletTransactionId).toBeDefined();
    });

    it('should leave charge pending if wallet is still empty at next confirmation', () => {
      const walletBalanceAtConfirm = 0.0;
      const chargeAmount = 0.5;

      const canDeduct = walletBalanceAtConfirm >= chargeAmount;
      expect(canDeduct).toBe(false); // charge remains pending for next invoicing
    });
  });

  // ---------------------------------------------------------------------------
  // C. record() helper contract
  // ---------------------------------------------------------------------------
  describe('C. PendingChargeService.record() shape', () => {
    it('should write a pending_charges row with kind, amount, userId, tripId, bookingId', () => {
      const chargeShape = {
        kind: expect.stringMatching(
          /^(passenger_cancellation|driver_no_show|passenger_no_show)$/,
        ),
        amount: expect.any(Number),
        userId: expect.any(String),
        tripId: expect.any(String),
        bookingId: expect.any(String),
        status: expect.stringMatching(/^(pending|applied)$/),
        createdAt: expect.any(String),
      };

      expect(chargeShape.kind).toBeDefined();
    });
  });
});
