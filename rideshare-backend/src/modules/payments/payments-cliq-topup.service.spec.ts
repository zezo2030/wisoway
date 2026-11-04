import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { getQueueToken } from '@nestjs/bull';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { PaymentsService } from './payments.service';
import { A2aCliqService } from './a2a-cliq.service';
import { WalletService } from '../wallet/wallet.service';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PlatformPricingService } from './platform-pricing.service';
import { PaymentEntity } from '../../database/entities/payment.entity';
import { CommunicationFeeEntity } from '../../database/entities/communication-fee.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import { PgUserRole } from '../../database/entities';

const makeRepo = () => ({
  create: jest.fn((data) => ({ ...data })),
  save: jest.fn(async (entity) => ({ id: 'pay-123', ...entity })),
  findOne: jest.fn(),
  count: jest.fn(),
});

describe('PaymentsService – CliQ wallet top-up', () => {
  let service: PaymentsService;
  let paymentRepo: ReturnType<typeof makeRepo>;
  let a2aCliqService: jest.Mocked<A2aCliqService>;
  let walletService: jest.Mocked<Partial<WalletService>>;
  let cliqPollQueue: { add: jest.Mock; remove: jest.Mock };

  const mockUser = { id: 'user-1', role: PgUserRole.RIDER };

  beforeEach(async () => {
    paymentRepo = makeRepo();
    a2aCliqService = {
      purchase: jest.fn(),
      paymentInquiry: jest.fn(),
      getToken: jest.fn(),
    } as unknown as jest.Mocked<A2aCliqService>;
    walletService = {
      creditPostedTopup: jest.fn(),
      assertDriverTopup: jest.fn().mockResolvedValue(undefined),
    };
    cliqPollQueue = { add: jest.fn().mockResolvedValue({}), remove: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        { provide: getRepositoryToken(PaymentEntity), useValue: paymentRepo },
        {
          provide: getRepositoryToken(CommunicationFeeEntity),
          useValue: makeRepo(),
        },
        { provide: getRepositoryToken(TripEntity), useValue: makeRepo() },
        {
          provide: getRepositoryToken(UserEntity),
          useValue: { findOne: jest.fn(async () => mockUser) },
        },
        { provide: DataSource, useValue: { createQueryRunner: jest.fn() } },
        {
          provide: NotificationsService,
          useValue: {
            sendToUser: jest.fn(),
            create: jest.fn().mockResolvedValue({}),
          },
        },
        { provide: A2aCliqService, useValue: a2aCliqService },
        { provide: PlatformPricingService, useValue: {} },
        { provide: WalletService, useValue: walletService },
        {
          provide: AdminAlertsService,
          useValue: {
            notifyWalletTopup: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: getQueueToken('cliq-poll'),
          useValue: cliqPollQueue,
        },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
  });

  // ─── createWalletTopup ──────────────────────────────────────────────────────

  describe('createWalletTopup', () => {
    describe('the number sent to CliQ', () => {
      beforeEach(() => {
        a2aCliqService.purchase.mockResolvedValue({
          MSGID: 'msg-1',
          errorCode: '0',
          description: 'Accepted',
        });
      });

      it.each([['0791234567'], ['٠٧٩١٢٣٤٥٦٧'], ['+962 79 123 4567']])(
        'sends the mobile %s in the gateway format',
        async (aliasValue) => {
          await service.createWalletTopup('user-1', {
            amount: 10,
            method: 'cliq_a2a',
            aliasType: 'MOBL',
            aliasValue,
          });

          expect(a2aCliqService.purchase).toHaveBeenCalledWith(
            expect.objectContaining({
              aliasType: 'MOBL',
              aliasValue: '00962791234567',
            }),
          );
        },
      );

      it('keeps an alias as typed', async () => {
        await service.createWalletTopup('user-1', {
          amount: 10,
          method: 'cliq_a2a',
          aliasType: 'ALIAS',
          aliasValue: ' ahmad@cliq ',
        });

        expect(a2aCliqService.purchase).toHaveBeenCalledWith(
          expect.objectContaining({
            aliasType: 'ALIAS',
            aliasValue: 'ahmad@cliq',
          }),
        );
      });

      it('refuses a non-Jordanian mobile before reaching the gateway', async () => {
        await expect(
          service.createWalletTopup('user-1', {
            amount: 10,
            method: 'cliq_a2a',
            aliasType: 'MOBL',
            aliasValue: '0501234567',
          }),
        ).rejects.toThrow(BadRequestException);

        expect(a2aCliqService.purchase).not.toHaveBeenCalled();
        expect(paymentRepo.save).not.toHaveBeenCalled();
      });
    });

    it('rejects cliq_a2a when aliasType is missing', async () => {
      await expect(
        service.createWalletTopup('user-1', {
          amount: 10,
          method: 'cliq_a2a',
          aliasValue: '00962777000000',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects cliq_a2a when aliasValue is missing', async () => {
      await expect(
        service.createWalletTopup('user-1', {
          amount: 10,
          method: 'cliq_a2a',
          aliasType: 'MOBL',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects manual top-up without proof image URL', async () => {
      await expect(
        service.createWalletTopup('user-1', {
          amount: 10,
          method: 'manual',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('answers once the request is sent, leaving the approval to polling', async () => {
      a2aCliqService.purchase.mockResolvedValue({
        MSGID: 'msg-abc',
        errorCode: '0',
        description: 'Accepted',
      });

      const result = await service.createWalletTopup('user-1', {
        amount: 5,
        method: 'cliq_a2a',
        aliasType: 'MOBL',
        aliasValue: '00962777000000',
      });

      expect(a2aCliqService.purchase).toHaveBeenCalledTimes(1);
      expect(a2aCliqService.paymentInquiry).not.toHaveBeenCalled();
      expect(result.status).toBe('pending');
      expect(result.paymentGatewayRef).toBe('msg-abc');
      expect(cliqPollQueue.add).toHaveBeenCalledTimes(1);
      expect(walletService.creditPostedTopup).not.toHaveBeenCalled();
    });

    it('stays inside the app limit even when the gateway is slow', async () => {
      a2aCliqService.purchase.mockResolvedValue({
        MSGID: null,
        errorCode: 'TIMEOUT',
        description: 'Timed out',
      });

      const result = await service.createWalletTopup('user-1', {
        amount: 5,
        method: 'cliq_a2a',
        aliasType: 'MOBL',
        aliasValue: '00962777000000',
      });

      const { timeoutMs } = a2aCliqService.purchase.mock.calls[0][0];
      expect(timeoutMs).toBeLessThan(10_000);
      expect(result.status).toBe('pending');
      expect(cliqPollQueue.add).toHaveBeenCalledTimes(1);
    });

    it('marks payment as rejected on an outright gateway refusal', async () => {
      a2aCliqService.purchase.mockResolvedValue({
        MSGID: 'msg-bad',
        errorCode: '3010',
        description: 'Self payment is not allowed',
      });

      await expect(
        service.createWalletTopup('user-1', {
          amount: 5,
          method: 'cliq_a2a',
          aliasType: 'ALIAS',
          aliasValue: 'badAlias',
        }),
      ).rejects.toThrow(BadRequestException);

      const lastSave = paymentRepo.save.mock.calls.at(-1)?.[0];
      expect(lastSave?.status).toBe('rejected');
      expect(cliqPollQueue.add).not.toHaveBeenCalled();
    });

    it('tells the user when sending fails but keeps checking the payment', async () => {
      a2aCliqService.purchase.mockRejectedValue(
        new BadRequestException('Failed to create A2A CliQ purchase'),
      );

      await expect(
        service.createWalletTopup('user-1', {
          amount: 5,
          method: 'cliq_a2a',
          aliasType: 'MOBL',
          aliasValue: '00962777000000',
        }),
      ).rejects.toThrow('تعذر إرسال طلب الدفع إلى CliQ');

      const lastSave = paymentRepo.save.mock.calls.at(-1)?.[0];
      expect(lastSave?.status).toBe('pending');
      expect(cliqPollQueue.add).toHaveBeenCalledTimes(1);
    });

    it('creates manual top-up correctly with proof URL', async () => {
      const result = await service.createWalletTopup('user-1', {
        amount: 100,
        method: 'manual',
        proofImageUrl: 'https://cdn.example.com/proof.jpg',
      });

      expect(a2aCliqService.purchase).not.toHaveBeenCalled();
      expect(result.method).toBe('manual');
      expect(result.status).toBe('pending');
    });
  });

  // ─── refreshCliqPaymentStatus ────────────────────────────────────────────────

  describe('refreshCliqPaymentStatus', () => {
    const pendingCliQ: Partial<PaymentEntity> = {
      id: 'pay-123',
      userId: 'user-1',
      method: 'cliq_a2a',
      status: 'pending',
      amount: 5,
      currency: 'JOD',
      paymentGatewayRef: 'trx-ref-001',
      transactionId: 'trx-ref-001',
    };

    it('credits wallet and marks approved on success status code', async () => {
      paymentRepo.findOne.mockResolvedValue({ ...pendingCliQ });
      a2aCliqService.paymentInquiry.mockResolvedValue({
        MessageTrxID: 'trx-ref-001',
        StatusCode: '000',
        StatusDescription: 'Approved',
      });

      const result = await service.refreshCliqPaymentStatus('pay-123');

      expect(walletService.creditPostedTopup).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'user-1',
          amount: 5,
          idempotencyKey: 'cliq-topup:pay-123',
        }),
      );
      expect(result.status).toBe('approved');
    });

    it('does NOT double-credit an already approved payment', async () => {
      paymentRepo.findOne.mockResolvedValue({
        ...pendingCliQ,
        status: 'approved',
      });
      a2aCliqService.paymentInquiry.mockResolvedValue({
        MessageTrxID: 'trx-ref-001',
        StatusCode: '000',
        StatusDescription: 'Approved',
      });

      await service.refreshCliqPaymentStatus('pay-123');
      expect(walletService.creditPostedTopup).not.toHaveBeenCalled();
    });

    it('marks payment rejected on failure status code', async () => {
      paymentRepo.findOne.mockResolvedValue({ ...pendingCliQ });
      a2aCliqService.paymentInquiry.mockResolvedValue({
        MessageTrxID: 'trx-ref-001',
        StatusCode: 'FAILED',
        StatusDescription: 'Payment failed',
      });

      const result = await service.refreshCliqPaymentStatus('pay-123');
      expect(result.status).toBe('rejected');
      expect(walletService.creditPostedTopup).not.toHaveBeenCalled();
    });

    it.each(['300', '306', '310'])(
      'keeps a payment open on %s, which a late approval can still turn into 0',
      async (StatusCode) => {
        paymentRepo.findOne.mockResolvedValue({ ...pendingCliQ });
        a2aCliqService.paymentInquiry.mockResolvedValue({
          MessageTrxID: 'trx-ref-001',
          StatusCode,
          StatusDescription: 'Not settled',
        });

        const result = await service.refreshCliqPaymentStatus('pay-123');

        expect(result.status).toBe('pending');
        expect(paymentRepo.save).not.toHaveBeenCalled();
      },
    );

    it('throws ForbiddenException when requesting user is not the owner', async () => {
      paymentRepo.findOne.mockResolvedValue({ ...pendingCliQ });
      await expect(
        service.refreshCliqPaymentStatus('pay-123', 'other-user'),
      ).rejects.toThrow(ForbiddenException);
    });

    it('throws NotFoundException when payment does not exist', async () => {
      paymentRepo.findOne.mockResolvedValue(null);
      await expect(service.refreshCliqPaymentStatus('pay-999')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('throws BadRequestException for non-cliq_a2a payment', async () => {
      paymentRepo.findOne.mockResolvedValue({
        ...pendingCliQ,
        method: 'manual',
      });
      await expect(service.refreshCliqPaymentStatus('pay-123')).rejects.toThrow(
        BadRequestException,
      );
    });
  });
});
