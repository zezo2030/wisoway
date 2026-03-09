import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import {
  PayoutRequestEntity,
  TripEntity,
  WalletAccountEntity,
  WalletTransactionEntity,
} from '../../database/entities';
import { WalletService } from './wallet.service';

describe('WalletService', () => {
  let service: WalletService;
  let walletAccountRepo: jest.Mocked<Repository<WalletAccountEntity>>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
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
      ],
    }).compile();

    service = module.get(WalletService);
    walletAccountRepo = module.get(getRepositoryToken(WalletAccountEntity));
  });

  it('returns existing wallet summary for driver', async () => {
    walletAccountRepo.findOne.mockResolvedValue({
      id: 'w1',
      userId: 'u1',
      accountType: 'driver',
      currency: 'EGP',
      balance: '20.00',
      isActive: true,
    } as any);

    const summary = await service.getWalletSummary('u1', 'driver');

    expect(summary.accountId).toBe('w1');
    expect(summary.balance).toBe(20);
    expect(summary.accountType).toBe('driver');
  });
});
