import { WalletAccountType } from '../../database/entities';
import {
  PendingChargeKind,
  PendingChargeStatus,
} from '../../database/entities/pending-charge.entity';
import {
  PendingChargesService,
  walletAccountTypeForCharge,
} from './pending-charges.service';

describe('PendingChargesService — collecting in the right currency', () => {
  let accounts: any[];
  let charges: any[];
  let savedTxs: any[];
  let service: PendingChargesService;

  beforeEach(() => {
    accounts = [
      { id: 'jod', currency: 'JOD', balance: '50.00' },
      { id: 'sar', currency: 'SAR', balance: '5.00' },
    ];
    savedTxs = [];
    charges = [
      {
        id: 'pc-1',
        userId: 'driver-1',
        kind: PendingChargeKind.DRIVER_TRIP_FEE,
        amount: '16.00',
        status: PendingChargeStatus.PENDING,
        tripId: 'trip-sa',
      },
    ];
    const manager = {
      createQueryBuilder: () => ({
        setLock: () => ({
          where: () => ({
            andWhere: () => ({
              orderBy: () => ({ getMany: async () => accounts }),
            }),
          }),
        }),
      }),
      create: (_e: any, data: any) => ({ ...data }),
      save: async (_e: any, row: any) => {
        if (row.referenceType) savedTxs.push(row);
        return { id: 'tx-1', ...row };
      },
    };
    const dataSource = {
      transaction: async (cb: any) => cb(manager),
      getRepository: () => ({
        findOne: async ({ where }: any) =>
          where.id === 'trip-sa' ? { id: 'trip-sa', currency: 'SAR' } : null,
      }),
    };
    service = new PendingChargesService(
      {
        find: async () => charges,
        save: async (c: any) => c,
      } as any,
      {} as any,
      {} as any,
      dataSource as any,
      { syncUserLegacyWalletMirror: jest.fn() } as any,
    );
  });

  it('leaves a riyal debt pending rather than paying it with dinars', async () => {
    const result = await service.collectOutstanding('driver-1', null);
    expect(result.applied).toHaveLength(0);
    expect(accounts[0].balance).toBe('50.00');
    expect(savedTxs).toHaveLength(0);
  });

  it('collects it once the riyal wallet covers it', async () => {
    accounts[1].balance = '20.00';
    const result = await service.collectOutstanding('driver-1', null);
    expect(result.applied).toHaveLength(1);
    expect(accounts[1].balance).toBe('4.00');
    expect(accounts[0].balance).toBe('50.00');
    expect(savedTxs[0]).toMatchObject({ accountId: 'sar', currency: 'SAR' });
  });
});

describe('walletAccountTypeForCharge', () => {
  it('routes a driver trip fee to the driver ledger', () => {
    expect(walletAccountTypeForCharge(PendingChargeKind.DRIVER_TRIP_FEE)).toBe(
      WalletAccountType.DRIVER,
    );
  });

  it('routes a driver no-show to the driver ledger', () => {
    expect(walletAccountTypeForCharge(PendingChargeKind.DRIVER_NO_SHOW)).toBe(
      WalletAccountType.DRIVER,
    );
  });

  it('routes passenger charges to the rider ledger', () => {
    expect(
      walletAccountTypeForCharge(PendingChargeKind.PASSENGER_NO_SHOW),
    ).toBe(WalletAccountType.RIDER);
    expect(
      walletAccountTypeForCharge(PendingChargeKind.PASSENGER_CANCELLATION),
    ).toBe(WalletAccountType.RIDER);
  });
});
