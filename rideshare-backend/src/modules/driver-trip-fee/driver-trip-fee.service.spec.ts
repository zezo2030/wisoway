import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, Logger } from '@nestjs/common';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  BookingEntity,
  PendingChargeEntity,
  TripEntity,
  UserEntity,
  WalletAccountEntity,
  WalletAccountType,
  WalletTransactionEntity,
} from '../../database/entities';
import { BookingStatus } from '../../database/entities/booking.entity';
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
        { provide: getRepositoryToken(PendingChargeEntity), useValue: {} },
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
  let tripSaveShouldFail: boolean;
  let recordedCharges: any[];
  let blindTxLookups: number;
  let lockedAccounts: any[];
  let loggedErrors: jest.SpyInstance;

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
    confirmedBookings = [
      { id: 'b-1', status: BookingStatus.CONFIRMED },
      { id: 'b-2', status: BookingStatus.IN_PROGRESS },
    ];
    tripSaveShouldFail = false;
    recordedCharges = [];
    blindTxLookups = 0;
    lockedAccounts = [account];
    // Several tests drive failure paths on purpose; keep the run's output clean
    // while still being able to assert the service shouted.
    loggedErrors = jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation(() => undefined);
    pendingCharges = {
      record: jest.fn().mockImplementation(async (params: any) => {
        const row = { id: `pc-${recordedCharges.length + 1}`, ...params };
        recordedCharges.push(row);
        return row;
      }),
    };

    // Honours where.status, so dropping a status from the service's filter
    // actually changes what comes back.
    const findBookings = ({ where }: any) => {
      const wanted = where?.status?.value ?? [];
      return confirmedBookings.filter((b: any) => wanted.includes(b.status));
    };

    const manager = {
      createQueryBuilder: () => ({
        setLock: () => ({
          where: () => ({
            andWhere: () => ({
              orderBy: () => ({ getMany: async () => lockedAccounts }),
            }),
          }),
        }),
      }),
      findOne: async (entity: any) => (entity === UserEntity ? driver : null),
      find: async (_entity: any, options: any) => findBookings(options ?? {}),
      create: (_entity: any, data: any) => ({ ...data }),
      save: async (entity: any, obj?: any) => {
        const row = obj ?? entity;
        if (row?.type) {
          // wallet_tx_idempotency_idx is UNIQUE in the real schema — a replay
          // that reaches this point must blow up exactly as Postgres would.
          if (savedTxs.some((t) => t.idempotencyKey === row.idempotencyKey)) {
            throw new Error(
              `duplicate key value violates unique constraint "wallet_tx_idempotency_idx"`,
            );
          }
          savedTxs.push(row);
        }
        if (row?.driverWalletChargeApplied !== undefined) savedTrips.push(row);
        return row;
      },
      update: async () => ({ affected: 1 }),
    };

    // A real transaction rolls back. The unique-index failure undoing the
    // balance mutation is the only thing preventing a concurrent double-debit,
    // so the fake has to model it or that property is untestable.
    const dataSource = {
      transaction: async (cb: any) => {
        const snapshot = {
          balance: account.balance,
          txs: [...savedTxs],
          freeTrip: driver.hasUsedLifetimeFreeTrip,
        };
        try {
          return await cb(manager);
        } catch (err) {
          account.balance = snapshot.balance;
          savedTxs.length = 0;
          savedTxs.push(...snapshot.txs);
          driver.hasUsedLifetimeFreeTrip = snapshot.freeTrip;
          throw err;
        }
      },
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
              if (tripSaveShouldFail) throw new Error('stamp failed');
              savedTrips.push(t);
              return t;
            },
          },
        },
        {
          provide: getRepositoryToken(BookingEntity),
          useValue: {
            find: async (options: any) => findBookings(options),
            update: async () => ({ affected: confirmedBookings.length }),
          },
        },
        { provide: getRepositoryToken(UserEntity), useValue: {} },
        {
          provide: getRepositoryToken(PendingChargeEntity),
          useValue: {
            findOne: async ({ where }: any) =>
              recordedCharges.find(
                (c) => c.tripId === where.tripId && c.kind === where.kind,
              ) ?? null,
          },
        },
        { provide: getRepositoryToken(WalletAccountEntity), useValue: {} },
        {
          provide: getRepositoryToken(WalletTransactionEntity),
          useValue: {
            findOne: async ({ where }: any) => {
              // Models the window where a racing transaction has not committed
              // yet, so this caller's guard read sees nothing.
              if (blindTxLookups > 0) {
                blindTxLookups -= 1;
                return null;
              }
              return (
                savedTxs.find(
                  (t) => t.idempotencyKey === where.idempotencyKey,
                ) ?? null
              );
            },
          },
        },
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
    confirmedBookings = [
      { id: 'b-1', status: BookingStatus.CONFIRMED },
      { id: 'b-2', status: BookingStatus.CONFIRMED },
    ];
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

  it('does not double-charge when the trip stamp fails and the sweep retries', async () => {
    account.balance = '0.00';

    // Run 1: nothing to debit, so the whole fee is carried forward — and then
    // the audit stamp never lands. That must not surface as a throw; the trip
    // has to be able to start regardless.
    tripSaveShouldFail = true;
    const first = trip();
    const firstResult = await service.chargeAtTripStart(first);
    expect(firstResult.pendingRemainder).toBe(1.6);
    expect(pendingCharges.record).toHaveBeenCalledTimes(1);
    // The stamp did not persist, so the in-memory entity must not claim it did.
    expect(first.driverWalletChargeApplied).toBe(false);

    // Task 9's sweep re-loads the trip from the DB, where the stamp never
    // landed, so driverWalletChargeApplied is still false.
    tripSaveShouldFail = false;
    const retried = trip();
    const second = await service.chargeAtTripStart(retried);

    // The wallet transaction written by run 1 is the idempotency record: the
    // retry must move no money and must not re-record the debt...
    expect(pendingCharges.record).toHaveBeenCalledTimes(1);
    expect(account.balance).toBe('0.00');
    expect(savedTxs).toHaveLength(1);
    expect(second.applied).toBe(false);
    expect(second.reason).toBe('already-charged');

    // ...but it must still converge by stamping the trip, or every future
    // sweep would retry this trip forever.
    expect(retried.driverWalletChargeApplied).toBe(true);
    expect(savedTrips).toContain(retried);
  });

  it('re-records a shortfall lost when the pending-charge insert failed', async () => {
    account.balance = '0.00';

    // The ledger commits, then the PendingCharge insert dies before any row
    // exists. Nothing is left to collect the debt but the audit row.
    pendingCharges.record.mockRejectedValueOnce(new Error('insert failed'));
    const first = trip();
    await service.chargeAtTripStart(first);
    expect(pendingCharges.record).toHaveBeenCalledTimes(1);
    expect(recordedCharges).toHaveLength(0);
    // Unstamped on purpose — that is what brings the sweep back.
    expect(first.driverWalletChargeApplied).toBe(false);

    const retried = trip();
    const second = await service.chargeAtTripStart(retried);

    expect(second.reason).toBe('already-charged');
    expect(second.pendingRemainder).toBe(1.6);
    expect(recordedCharges).toHaveLength(1);
    expect(recordedCharges[0]).toMatchObject({
      userId: 'driver-1',
      kind: PendingChargeKind.DRIVER_TRIP_FEE,
      amount: 1.6,
      tripId: 'trip-1',
    });
    expect(retried.driverWalletChargeApplied).toBe(true);
  });

  it('rolls the balance back and converges when it loses a concurrent race', async () => {
    await service.chargeAtTripStart(trip());
    expect(account.balance).toBe('8.40');

    // The loser's guard read lands before the winner commits, so it sees no
    // audit row, proceeds to debit, and only then hits the unique index.
    blindTxLookups = 1;
    const loser = trip();
    const result = await service.chargeAtTripStart(loser);

    expect(result.applied).toBe(false);
    expect(result.reason).toBe('already-charged');
    // Rolled back by the transaction — a second 1.60 would leave 6.80.
    expect(account.balance).toBe('8.40');
    expect(savedTxs).toHaveLength(1);
    expect(pendingCharges.record).not.toHaveBeenCalled();
    expect(loser.driverWalletChargeApplied).toBe(true);
  });

  it('charges a trip whose bookings the processor already flipped to IN_PROGRESS', async () => {
    confirmedBookings = [
      { id: 'b-1', status: BookingStatus.IN_PROGRESS },
      { id: 'b-2', status: BookingStatus.IN_PROGRESS },
    ];
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(1.6);
    expect(result.reason).toBeUndefined();
  });

  it('charges nothing when the driver has no wallet ledger account', async () => {
    lockedAccounts = [];
    const result = await service.chargeAtTripStart(trip());
    expect(result.charged).toBe(0);
    // Records nothing: with no account there is no audit row to dedupe a
    // retry against, so recording here would double-record on the next sweep.
    expect(result.pendingRemainder).toBe(0);
    expect(pendingCharges.record).not.toHaveBeenCalled();
    expect(loggedErrors).toHaveBeenCalledWith(
      expect.stringContaining('has no DRIVER wallet account'),
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
