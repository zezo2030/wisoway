import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Repository } from 'typeorm';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { PaymentsService } from './payments.service';
import { UpdateManualPaymentDto } from './dto/update-manual-payment.dto';
import { PaymentEntity } from '../../database/entities/payment.entity';

describe('PaymentsService.updateManualPayment', () => {
  const pending = {
    id: 'pay-1',
    userId: 'user-1',
    method: 'manual',
    status: 'pending',
    proofImageUrl: null,
    walletNumber: null,
    transactionId: 'keep-me',
  };
  let paymentRepo: { findOne: jest.Mock; save: jest.Mock };
  let service: PaymentsService;

  beforeEach(() => {
    paymentRepo = {
      findOne: jest.fn(async () => ({ ...pending })),
      save: jest.fn(async (entity: unknown) => entity),
    };
    service = Object.create(PaymentsService.prototype) as PaymentsService;
    (
      service as unknown as { paymentRepo: Partial<Repository<PaymentEntity>> }
    ).paymentRepo = paymentRepo as unknown as Repository<PaymentEntity>;
  });

  it('writes only the fields that were sent', async () => {
    const updated = await service.updateManualPayment('pay-1', 'user-1', {
      proofImageUrl: 'private-document:a.jpg',
      walletNumber: '0790000000',
    });

    expect(updated.proofImageUrl).toBe('private-document:a.jpg');
    expect(updated.walletNumber).toBe('0790000000');
    expect(updated.transactionId).toBe('keep-me');
    expect(paymentRepo.save).toHaveBeenCalled();
  });

  it('refuses a payment that does not exist', async () => {
    paymentRepo.findOne.mockResolvedValue(null);
    await expect(
      service.updateManualPayment('pay-1', 'user-1', { walletNumber: '1' }),
    ).rejects.toThrow(NotFoundException);
  });

  it('refuses another user', async () => {
    await expect(
      service.updateManualPayment('pay-1', 'user-2', { walletNumber: '1' }),
    ).rejects.toThrow(ForbiddenException);
    expect(paymentRepo.save).not.toHaveBeenCalled();
  });

  it('refuses a payment already decided', async () => {
    paymentRepo.findOne.mockResolvedValue({ ...pending, status: 'approved' });
    await expect(
      service.updateManualPayment('pay-1', 'user-1', { walletNumber: '1' }),
    ).rejects.toThrow(BadRequestException);
    expect(paymentRepo.save).not.toHaveBeenCalled();
  });

  it('refuses a payment that is not manual', async () => {
    paymentRepo.findOne.mockResolvedValue({ ...pending, method: 'cliq_a2a' });
    await expect(
      service.updateManualPayment('pay-1', 'user-1', { walletNumber: '1' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('refuses an empty update', async () => {
    await expect(
      service.updateManualPayment('pay-1', 'user-1', {}),
    ).rejects.toThrow(BadRequestException);
    expect(paymentRepo.findOne).not.toHaveBeenCalled();
  });
});

describe('UpdateManualPaymentDto', () => {
  const errorsFor = (proofImageUrl: string) =>
    validate(plainToInstance(UpdateManualPaymentDto, { proofImageUrl }));

  it('accepts a private receipt reference', async () => {
    await expect(errorsFor('private-document:a.jpg')).resolves.toHaveLength(0);
  });

  it('refuses a public link', async () => {
    const errors = await errorsFor('https://host/uploads/general/a.jpg');
    expect(errors[0].property).toBe('proofImageUrl');
  });
});
