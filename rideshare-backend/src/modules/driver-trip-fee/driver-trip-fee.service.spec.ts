import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  BookingEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletTransactionEntity,
} from '../../database/entities';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PendingChargesService } from '../pending-charges/pending-charges.service';
import { WalletService } from '../wallet/wallet.service';
import { DriverTripFeeService } from './driver-trip-fee.service';

describe('DriverTripFeeService — quoting and publish guard', () => {
  let service: DriverTripFeeService;
  let walletService: { getWalletSummary: jest.Mock };
  let pricing: { getActiveFeeRow: jest.Mock };

  beforeEach(async () => {
    walletService = { getWalletSummary: jest.fn() };
    pricing = {
      getActiveFeeRow: jest.fn().mockResolvedValue({
        driverUnlockPercent: 10,
        feeAmount: 0,
        currency: 'JOD',
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriverTripFeeService,
        { provide: WalletService, useValue: walletService },
        { provide: PlatformPricingService, useValue: pricing },
        { provide: PendingChargesService, useValue: { record: jest.fn() } },
        { provide: DataSource, useValue: { transaction: jest.fn() } },
        { provide: getRepositoryToken(TripEntity), useValue: {} },
        { provide: getRepositoryToken(BookingEntity), useValue: {} },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        { provide: getRepositoryToken(WalletAccountEntity), useValue: {} },
        { provide: getRepositoryToken(WalletTransactionEntity), useValue: {} },
      ],
    }).compile();

    service = module.get(DriverTripFeeService);
  });

  it('charges on every seat, not on booked seats', async () => {
    const quote = await service.computeExpectedFee({
      seatPrice: 4,
      totalSeats: 4,
      currency: 'JOD',
    });
    expect(quote.amount).toBe(1.6);
    expect(quote.percent).toBe(10);
    expect(quote.totalSeats).toBe(4);
  });

  it('rounds to two decimals', async () => {
    const quote = await service.computeExpectedFee({
      seatPrice: 3.33,
      totalSeats: 3,
      currency: 'JOD',
    });
    expect(quote.amount).toBe(1.0);
  });

  it('falls back to the legacy flat fee when the percent is zero', async () => {
    pricing.getActiveFeeRow.mockResolvedValue({
      driverUnlockPercent: 0,
      feeAmount: 0.75,
      currency: 'JOD',
    });
    const quote = await service.computeExpectedFee({
      seatPrice: 4,
      totalSeats: 4,
    });
    expect(quote.amount).toBe(0.75);
  });

  it('allows publishing when the balance exactly equals the fee', async () => {
    walletService.getWalletSummary.mockResolvedValue({
      balance: 1.6,
      currency: 'JOD',
    });
    await expect(
      service.assertDriverCanCoverTripFee('driver-1', {
        seatPrice: 4,
        totalSeats: 4,
      }),
    ).resolves.toMatchObject({ amount: 1.6 });
    expect(walletService.getWalletSummary).toHaveBeenCalledWith(
      'driver-1',
      WalletAccountType.DRIVER,
    );
  });

  it('blocks publishing one fils below the fee', async () => {
    walletService.getWalletSummary.mockResolvedValue({
      balance: 1.59,
      currency: 'JOD',
    });
    await expect(
      service.assertDriverCanCoverTripFee('driver-1', {
        seatPrice: 4,
        totalSeats: 4,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('blocks publishing on a negative balance', async () => {
    walletService.getWalletSummary.mockResolvedValue({
      balance: -3,
      currency: 'JOD',
    });
    await expect(
      service.assertDriverCanCoverTripFee('driver-1', {
        seatPrice: 4,
        totalSeats: 4,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
