import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import {
  PayoutRequestEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletTransactionEntity,
} from '../../database/entities';
import { WalletService } from './wallet.service';
import { PlatformPricingService } from '../payments/platform-pricing.service';
import { PlatformSettingsService } from '../platform-settings/platform-settings.service';
import { DriverWalletPolicyService } from './driver-wallet-policy.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('WalletService', () => {
  let service: WalletService;
  let walletAccountRepo: jest.Mocked<Repository<WalletAccountEntity>>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        {
          provide: PlatformSettingsService,
          useValue: { getNumber: jest.fn().mockResolvedValue(10) },
        },
        {
          provide: DriverWalletPolicyService,
          useValue: { minimum: jest.fn().mockResolvedValue(5) },
        },
        {
          provide: NotificationsService,
          useValue: { create: jest.fn().mockResolvedValue({}) },
        },
        WalletService,
        {
          provide: DataSource,
          useValue: {
            transaction: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(WalletAccountEntity),
          useValue: {
            find: jest.fn(),
            findOne: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(WalletTransactionEntity),
          useValue: {
            findOne: jest.fn(),
            find: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(PayoutRequestEntity),
          useValue: {
            create: jest.fn(),
            save: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: {
            findOne: jest.fn(),
          },
        },
        {
          provide: getRepositoryToken(UserEntity),
          useValue: {
            findOne: jest.fn(),
          },
        },
        {
          provide: PlatformPricingService,
          useValue: {
            getActiveFeeRow: jest.fn().mockResolvedValue(null),
            driverUnlockPricing: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(WalletService);
    walletAccountRepo = module.get(getRepositoryToken(WalletAccountEntity));
  });

  it('returns existing wallet summary for driver', async () => {
    walletAccountRepo.find.mockResolvedValue([
      {
        id: 'w1',
        userId: 'u1',
        accountType: 'driver',
        currency: 'JOD',
        balance: '20.00',
        isActive: true,
      },
    ] as any);

    const summary = await service.getWalletSummary('u1', 'driver');

    expect(summary.accountId).toBe('w1');
    expect(summary.balance).toBe(20);
    expect(summary.accountType).toBe('driver');
  });

  it('reports available balance net of funds reserved by active trip holds', async () => {
    walletAccountRepo.find.mockResolvedValue([
      {
        id: 'w1',
        userId: 'u1',
        accountType: 'driver',
        currency: 'JOD',
        balance: '20.00',
        reservedBalance: '0.80',
        isActive: true,
      },
    ] as any);

    const summary = await service.getWalletSummary('u1', 'driver');

    expect(summary.balance).toBe(20);
    expect(summary.reservedBalance).toBe(0.8);
    expect(summary.availableBalance).toBe(19.2);
  });

  it('prefers non-zero JOD account over empty legacy currency when both exist', async () => {
    walletAccountRepo.find.mockResolvedValue([
      {
        id: 'egp',
        userId: 'u1',
        accountType: 'rider',
        currency: 'EGP',
        balance: '0.00',
        isActive: true,
      },
      {
        id: 'jod',
        userId: 'u1',
        accountType: 'rider',
        currency: 'JOD',
        balance: '15.50',
        isActive: true,
      },
    ] as any);

    const summary = await service.getWalletSummary('u1', 'passenger');

    expect(summary.accountId).toBe('jod');
    expect(summary.currency).toBe('JOD');
    expect(summary.balance).toBe(15.5);
  });

  describe('local currency', () => {
    const account = (id: string, currency: string, balance: string) =>
      ({
        id,
        userId: 'u1',
        accountType: 'rider',
        currency,
        balance,
        reservedBalance: '0',
        isActive: true,
      }) as any;

    beforeEach(() => {
      walletAccountRepo.findOne.mockResolvedValue(null);
      walletAccountRepo.create.mockImplementation((v: any) => v);
      walletAccountRepo.save.mockImplementation(async (v: any) => ({
        id: 'created',
        ...v,
      }));
    });

    it('shows an empty wallet in the local currency', async () => {
      walletAccountRepo.find.mockResolvedValue([account('jod', 'JOD', '0')]);

      const summary = await service.getWalletSummary('u1', 'passenger', 'SAR');

      expect(summary.currency).toBe('SAR');
      expect(summary.balance).toBe(0);
      expect(walletAccountRepo.save).toHaveBeenCalledWith(
        expect.objectContaining({ currency: 'SAR', accountType: 'rider' }),
      );
    });

    it('reuses the existing local-currency account', async () => {
      walletAccountRepo.find.mockResolvedValue([
        account('jod', 'JOD', '0'),
        account('sar', 'SAR', '0'),
      ]);

      const summary = await service.getWalletSummary('u1', 'passenger', 'SAR');

      expect(summary.accountId).toBe('sar');
      expect(walletAccountRepo.save).not.toHaveBeenCalled();
    });

    it('never relabels money held in another currency', async () => {
      walletAccountRepo.find.mockResolvedValue([account('jod', 'JOD', '7.00')]);

      const summary = await service.getWalletSummary('u1', 'passenger', 'SAR');

      expect(summary.accountId).toBe('jod');
      expect(summary.currency).toBe('JOD');
      expect(summary.balance).toBe(7);
    });

    it('keeps showing a debt held in another currency', async () => {
      walletAccountRepo.find.mockResolvedValue([
        account('jod', 'JOD', '-3.00'),
        account('sar', 'SAR', '0'),
      ]);

      const summary = await service.getWalletSummary('u1', 'driver', 'SAR');

      expect(summary.accountId).toBe('jod');
      expect(summary.balance).toBe(-3);
    });

    it('resolves the currency from the reported country first', async () => {
      await expect(service.resolveLocalCurrency('u1', 'sa')).resolves.toBe(
        'SAR',
      );
    });

    it('falls back to the phone number country', async () => {
      const userRepo = (service as any).userRepo;
      userRepo.findOne.mockResolvedValue({
        id: 'u1',
        phoneNumber: '+966501234567',
      });

      await expect(service.resolveLocalCurrency('u1')).resolves.toBe('SAR');
      await expect(service.resolveLocalCurrency('u1', 'XX')).resolves.toBe(
        'SAR',
      );
    });

    it('returns null when neither country nor phone is known', async () => {
      const userRepo = (service as any).userRepo;
      userRepo.findOne.mockResolvedValue({ id: 'u1', phoneNumber: null });

      await expect(service.resolveLocalCurrency('u1')).resolves.toBeNull();
    });
  });
});
