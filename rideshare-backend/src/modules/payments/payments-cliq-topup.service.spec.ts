import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { PaymentsService } from './payments.service';
import { A2aCliqService } from './a2a-cliq.service';
import { WalletService } from '../wallet/wallet.service';
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
    };

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
        { provide: NotificationsService, useValue: { sendToUser: jest.fn() } },
        { provide: A2aCliqService, useValue: a2aCliqService },
        { provide: PlatformPricingService, useValue: {} },
        { provide: WalletService, useValue: walletService },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
  });

  // ─── createWalletTopup ──────────────────────────────────────────────────────

  describe('createWalletTopup', () => {
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

    it('creates pending payment and calls purchase for cliq_a2a', async () => {
      a2aCliqService.purchase.mockResolvedValue({
        errorCode: 0,
        description: 'Success',
        MSGID: 'msg-abc',
      });

      const result = await service.createWalletTopup('user-1', {
        amount: 5,
        method: 'cliq_a2a',
        aliasType: 'MOBL',
        aliasValue: '00962777000000',
      });

      expect(a2aCliqService.purchase).toHaveBeenCalledTimes(1);
      expect(paymentRepo.save).toHaveBeenCalledTimes(2); // initial + gateway ref
      expect(result.method).toBe('cliq_a2a');
    });

    it('marks payment as rejected when purchase gateway returns error', async () => {
      a2aCliqService.purchase.mockResolvedValue({
        errorCode: 5,
        description: 'Invalid alias',
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
