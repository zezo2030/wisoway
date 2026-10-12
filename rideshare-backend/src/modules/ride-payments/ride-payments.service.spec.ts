import { BadRequestException, ConflictException } from '@nestjs/common';
import {
  RIDE_FARE_POLL_ATTEMPTS,
  RidePaymentsService,
} from './ride-payments.service';
import { parseCliqPayer, resolvePaymentChoice } from './cliq-payer';

describe('parseCliqPayer', () => {
  it.each([
    ['0791234567', '00962791234567'],
    ['791234567', '00962791234567'],
    ['+962 79 123 4567', '00962791234567'],
    ['00962791234567', '00962791234567'],
  ])('reads the mobile %s as %s', (raw, value) => {
    expect(parseCliqPayer(raw)).toEqual({ type: 'MOBL', value });
  });

  it('keeps an alias as typed', () => {
    expect(parseCliqPayer('ahmad@cliq')).toEqual({
      type: 'ALIAS',
      value: 'ahmad@cliq',
    });
  });

  it('rejects a non-Jordanian number and junk', () => {
    expect(parseCliqPayer('0501234567')).toBeNull();
    expect(parseCliqPayer('a b')).toBeNull();
    expect(parseCliqPayer('')).toBeNull();
  });
});

describe('resolvePaymentChoice', () => {
  it('defaults to cash', () => {
    expect(resolvePaymentChoice(undefined, 'SAR', null)).toEqual({
      method: 'cash',
      payerCliqAlias: null,
    });
  });

  it('refuses CliQ outside Jordan', () => {
    expect(() => resolvePaymentChoice('cliq', 'SAR', 'ahmad@cliq')).toThrow(
      BadRequestException,
    );
  });

  it('needs somewhere to send the CliQ request', () => {
    expect(() => resolvePaymentChoice('cliq', 'JOD', null)).toThrow(
      BadRequestException,
    );
  });
});

describe('RidePaymentsService', () => {
  let bookingRepo: any;
  let tripRepo: any;
  let paymentRepo: any;
  let cliq: any;
  let wallet: any;
  let notifications: any;
  let complaints: any;
  let pollQueue: any;
  let service: RidePaymentsService;

  const trip = { id: 't1', driverId: 'd1', currency: 'JOD' };
  const booking = (over: any = {}) => ({
    id: 'b1',
    tripId: 't1',
    userId: 'p1',
    status: 'completed',
    totalAmount: '2.50',
    paymentMethod: 'cash',
    paymentStatus: 'pending',
    payerCliqAlias: null,
    passengerPaymentId: null,
    settledAt: null,
    paymentDisputedAt: null,
    ...over,
  });

  beforeEach(() => {
    bookingRepo = {
      find: jest.fn().mockResolvedValue([]),
      findOne: jest.fn(),
      save: jest.fn().mockImplementation(async (b: any) => b),
    };
    tripRepo = { findOne: jest.fn().mockResolvedValue(trip) };
    paymentRepo = {
      create: jest.fn().mockImplementation((p: any) => p),
      save: jest
        .fn()
        .mockImplementation(async (p: any) => ({ id: 'pay1', ...p })),
      findOne: jest.fn(),
      update: jest.fn(),
    };
    cliq = {
      purchase: jest.fn().mockResolvedValue({ errorCode: '0', MSGID: 'm1' }),
      paymentInquiry: jest.fn(),
    };
    wallet = { creditPostedTopup: jest.fn().mockResolvedValue({}) };
    notifications = { sendPush: jest.fn().mockResolvedValue(undefined) };
    complaints = { create: jest.fn().mockResolvedValue({ id: 'c1' }) };
    pollQueue = { add: jest.fn().mockResolvedValue(undefined) };
    service = new RidePaymentsService(
      bookingRepo,
      tripRepo,
      paymentRepo,
      cliq,
      wallet,
      notifications,
      complaints,
      pollQueue,
    );
  });

  describe('openForTrip', () => {
    it('asks cash passengers to pay the driver', async () => {
      bookingRepo.find.mockResolvedValue([booking()]);

      await service.openForTrip('t1');

      expect(cliq.purchase).not.toHaveBeenCalled();
      expect(notifications.sendPush).toHaveBeenCalledWith(
        'p1',
        expect.objectContaining({ type: 'ride_payment_due' }),
      );
    });

    it('sends CliQ passengers a request-to-pay and watches it', async () => {
      const b = booking({
        paymentMethod: 'cliq',
        payerCliqAlias: '00962791234567',
      });
      bookingRepo.find.mockResolvedValue([b]);

      await service.openForTrip('t1');

      expect(cliq.purchase).toHaveBeenCalledWith(
        expect.objectContaining({
          aliasType: 'MOBL',
          aliasValue: '00962791234567',
          amount: 2.5,
        }),
      );
      expect(b.paymentStatus).toBe('requested');
      expect(b.passengerPaymentId).toBe('pay1');
      expect(pollQueue.add).toHaveBeenCalled();
    });

    it('fails at once when the bank refuses the request outright', async () => {
      const b = booking({
        paymentMethod: 'cliq',
        payerCliqAlias: 'ahmad@cliq',
      });
      bookingRepo.find.mockResolvedValue([b]);
      cliq.purchase.mockResolvedValue({ errorCode: '3010' });

      await service.openForTrip('t1');

      expect(b.paymentStatus).toBe('failed');
      expect(pollQueue.add).not.toHaveBeenCalled();
    });
  });

  describe('pollCliq', () => {
    const pending = {
      id: 'pay1',
      bookingId: 'b1',
      status: 'pending',
      transactionId: 'trx',
    };

    it("credits the driver's wallet with the full fare once paid", async () => {
      const b = booking({ paymentMethod: 'cliq', paymentStatus: 'requested' });
      paymentRepo.findOne.mockResolvedValue({ ...pending });
      bookingRepo.findOne.mockResolvedValue(b);
      cliq.paymentInquiry.mockResolvedValue({ StatusCode: '0' });

      await service.pollCliq({ paymentId: 'pay1', attempt: 3 });

      expect(wallet.creditPostedTopup).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'd1',
          amount: 2.5,
          idempotencyKey: 'ride-fare:b1',
          type: 'trip_payment',
        }),
      );
      expect(b.paymentStatus).toBe('paid');
      expect(b.settledAt).toBeInstanceOf(Date);
    });

    it('keeps waiting on a code that may still turn into a payment', async () => {
      paymentRepo.findOne.mockResolvedValue({ ...pending });
      cliq.paymentInquiry.mockResolvedValue({ StatusCode: '310' });

      await service.pollCliq({ paymentId: 'pay1', attempt: 3 });

      expect(pollQueue.add).toHaveBeenCalledWith(
        'poll-ride-fare',
        { paymentId: 'pay1', attempt: 4 },
        expect.anything(),
      );
      expect(wallet.creditPostedTopup).not.toHaveBeenCalled();
    });

    it('gives up when the window runs out', async () => {
      const b = booking({ paymentMethod: 'cliq', paymentStatus: 'requested' });
      paymentRepo.findOne.mockResolvedValue({ ...pending });
      bookingRepo.findOne.mockResolvedValue(b);
      cliq.paymentInquiry.mockResolvedValue({ StatusCode: '310' });

      await service.pollCliq({
        paymentId: 'pay1',
        attempt: RIDE_FARE_POLL_ATTEMPTS,
      });

      expect(b.paymentStatus).toBe('failed');
      expect(notifications.sendPush).toHaveBeenCalledWith(
        'p1',
        expect.objectContaining({ type: 'ride_payment_failed' }),
      );
    });
  });

  describe('confirmCash', () => {
    it('records the cash payment', async () => {
      const b = booking();
      bookingRepo.findOne.mockResolvedValue(b);

      const view = await service.confirmCash('b1', 'd1', { received: true });

      expect(view.status).toBe('paid');
      expect(complaints.create).not.toHaveBeenCalled();
    });

    it('files a payment complaint when the passenger did not pay', async () => {
      bookingRepo.findOne.mockResolvedValue(booking());

      const view = await service.confirmCash('b1', 'd1', {
        received: false,
        note: 'رفض الدفع',
      });

      expect(view.status).toBe('disputed');
      expect(complaints.create).toHaveBeenCalledWith('d1', {
        againstUserId: 'p1',
        tripId: 't1',
        bookingId: 'b1',
        category: 'payment',
        body: 'رفض الدفع',
      });
    });

    it('keeps the first answer', async () => {
      bookingRepo.findOne.mockResolvedValue(booking({ paymentStatus: 'paid' }));

      await service.confirmCash('b1', 'd1', { received: false });

      expect(bookingRepo.save).not.toHaveBeenCalled();
      expect(complaints.create).not.toHaveBeenCalled();
    });

    it('is not for CliQ fares', async () => {
      bookingRepo.findOne.mockResolvedValue(
        booking({ paymentMethod: 'cliq', paymentStatus: 'requested' }),
      );
      await expect(
        service.confirmCash('b1', 'd1', { received: true }),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('switchToCash', () => {
    it('settles instead when a late CliQ approval already came in', async () => {
      const b = booking({
        paymentMethod: 'cliq',
        paymentStatus: 'failed',
        passengerPaymentId: 'pay1',
      });
      bookingRepo.findOne.mockResolvedValue(b);
      paymentRepo.findOne.mockResolvedValue({
        id: 'pay1',
        bookingId: 'b1',
        status: 'pending',
        transactionId: 'trx',
      });
      cliq.paymentInquiry.mockResolvedValue({ StatusCode: '0' });

      await service.switchToCash('b1', 'p1');

      // Paid by CliQ after all — not owed again in cash.
      expect(b.paymentMethod).toBe('cliq');
      expect(b.paymentStatus).toBe('paid');
    });

    it('moves a failed CliQ fare to cash for the driver to confirm', async () => {
      const b = booking({ paymentMethod: 'cliq', paymentStatus: 'failed' });
      bookingRepo.findOne.mockResolvedValue(b);

      await service.switchToCash('b1', 'p1');

      expect(b.paymentMethod).toBe('cash');
      expect(b.paymentStatus).toBe('pending');
      expect(notifications.sendPush).toHaveBeenCalledWith(
        'd1',
        expect.objectContaining({ type: 'ride_payment_cash_switch' }),
      );
    });
  });
});
