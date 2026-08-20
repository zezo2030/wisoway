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
import { PendingChargeKind } from '../../database/entities/pending-charge.entity';
import { TripStatus } from '../../database/entities/shared.enums';
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

describe('DriverTripFeeService.chargeAtTripStart', () => {
  let service: DriverTripFeeService;
  let account: any;
  let driver: any;
  let savedTxs: any[];
  let savedTrips: any[];
  let confirmedBookings: any[];
  let pendingCharges: { record: jest.Mock };

  const trip = () =>
    ({
      id: 'trip-1',
      driverId: 'driver-1',
      price: 4,
      totalSeats: 4,
      currency: 'JOD',
      status: TripStatus.IN_PROGRESS,
      driverWalletChargeApplied: false,
    }) as any;

  beforeEach(async () => {
    account = {
      id: 'acc-1',
      userId: 'driver-1',
      accountType: WalletAccountType.DRIVER,
      currency: 'JOD',
      balance: '10.00',
    };
    driver = { id: 'driver-1', hasUsedLifetimeFreeTrip: true };
    savedTxs = [];
    savedTrips = [];
    confirmedBookings = [{ id: 'b-1' }, { id: 'b-2' }];
    pendingCharges = { record: jest.fn().mockResolvedValue({ id: 'pc-1' }) };

    const manager = {
      createQueryBuilder: () => ({
        setLock: () => ({
          where: () => ({
            andWhere: () => ({
              orderBy: () => ({ getMany: async () => [account] }),
            }),
          }),
        }),
      }),
      findOne: async (entity: any) => (entity === UserEntity ? driver : null),
      find: async () => confirmedBookings,
      create: (_entity: any, data: any) => ({ ...data }),
      save: async (entity: any, obj?: any) => {
        const row = obj ?? entity;
        if (row?.type) savedTxs.push(row);
        if (row?.driverWalletChargeApplied !== undefined) savedTrips.push(row);
        return row;
      },
      update: async () => ({ affected: 1 }),
    };

    const dataSource = {
      transaction: async (cb: any) => cb(manager),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriverTripFeeService,
        {
          provide: WalletService,
          useValue: {
            getWalletSummary: jest.fn(),
            syncUserLegacyWalletMirror: jest.fn().mockResolvedValue(undefined),
          },
        },
        {
          provide: PlatformPricingService,
          useValue: {
            getActiveFeeRow: jest.fn().mockResolvedValue({
              driverUnlockPercent: 10,
              feeAmount: 0,
              currency: 'JOD',
            }),
          },
        },
        { provide: PendingChargesService, useValue: pendingCharges },
        { provide: DataSource, useValue: dataSource },
        {
          provide: getRepositoryToken(TripEntity),
          useValue: {
            save: async (t: any) => {
              savedTrips.push(t);
              return t;
            },
          },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: {
            find: async () => confirmedBookings,
            update: async () => ({ affected: confirmedBookings.length }),
          },
        },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        { provide: getRepositoryToken(WalletAccountEntity), useValue: {} },
        { provide: getRepositoryToken(WalletTransactionEntity), useValue: {} },
      ],
    }).compile();

    service = module.get(DriverTripFeeService);
  });

  it('debits the full all-seats fee when the balance covers it', async () => {
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.6);
    expect(result.pendingRemainder).toBe(0);
    expect(account.balance).toBe('8.40');
    expect(pendingCharges.record).not.toHaveBeenCalled();
  });

  it('charges on all four seats even though only two are booked', async () => {
    confirmedBookings = [{ id: 'b-1' }, { id: 'b-2' }];
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.6);
  });

  it('stamps the trip so a second run is a no-op', async () => {
    const t = trip();
    await service.chargeAtTripStart(t);
    const balanceAfterFirst = account.balance;

    // No manual flag flip — the first call must have stamped the trip itself.
    expect(t.driverWalletChargeApplied).toBe(true);

    const second = await service.chargeAtTripStart(t);

    expect(second.applied).toBe(false);
    expect(second.reason).toBe('already-charged');
    expect(account.balance).toBe(balanceAfterFirst);
  });

  it('charges nothing when no bookings were confirmed', async () => {
    confirmedBookings = [];
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    expect(result.reason).toBe('no-bookings');
    expect(account.balance).toBe('10.00');
    expect(savedTxs).toHaveLength(1);
    expect(savedTxs[0].amount).toBe('0.00');
  });

  it('consumes the lifetime free trip instead of charging', async () => {
    driver.hasUsedLifetimeFreeTrip = false;
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    expect(result.reason).toBe('free-trip');
    expect(driver.hasUsedLifetimeFreeTrip).toBe(true);
    expect(account.balance).toBe('10.00');
    expect(savedTxs[0].metadata.freeTripApplied).toBe(true);
  });

  it('debits what it can and records the remainder as a pending charge', async () => {
    account.balance = '1.00';
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.0);
    expect(result.pendingRemainder).toBe(0.6);
    expect(account.balance).toBe('0.00');
    expect(pendingCharges.record).toHaveBeenCalledWith({
      userId: 'driver-1',
      kind: PendingChargeKind.DRIVER_TRIP_FEE,
      amount: 0.6,
      tripId: 'trip-1',
    });
  });

  it('records the whole fee as pending on a zero balance', async () => {
    account.balance = '0.00';
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    expect(result.pendingRemainder).toBe(1.6);
    expect(pendingCharges.record).toHaveBeenCalledWith(
      expect.objectContaining({ amount: 1.6 }),
    );
  });

  it('snapshots the pricing basis onto the transaction metadata', async () => {
    await service.chargeAtTripStart(trip());
    expect(savedTxs[0].metadata).toMatchObject({
      seatPrice: 4,
      totalSeats: 4,
      percent: 10,
      formula: 'seatPrice * totalSeats * percent%',
    });
  });
});
