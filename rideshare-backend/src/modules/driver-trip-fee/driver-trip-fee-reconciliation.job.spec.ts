import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { DriverTripFeeService } from './driver-trip-fee.service';
import { DriverTripFeeReconciliationJob } from './driver-trip-fee-reconciliation.job';

describe('DriverTripFeeReconciliationJob', () => {
  let job: DriverTripFeeReconciliationJob;
  let tripRepo: any;
  let driverTripFee: any;
  let qb: any;

  const params: Record<string, any> = {};

  beforeEach(async () => {
    for (const k of Object.keys(params)) delete params[k];
    qb = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn(function (this: any, _sql: string, p?: any) {
        Object.assign(params, p ?? {});
        return this;
      }),
      orderBy: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getMany: jest.fn().mockResolvedValue([]),
    };
    tripRepo = { createQueryBuilder: jest.fn(() => qb) };
    driverTripFee = {
      chargeAtTripStart: jest.fn().mockResolvedValue({
        tripId: 't1',
        charged: 1.6,
        pendingRemainder: 0,
        currency: 'JOD',
        applied: true,
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriverTripFeeReconciliationJob,
        { provide: getRepositoryToken(TripEntity), useValue: tripRepo },
        { provide: DriverTripFeeService, useValue: driverTripFee },
      ],
    }).compile();

    job = module.get(DriverTripFeeReconciliationJob);
  });

  afterEach(() => {
    delete process.env.DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES;
    delete process.env.DRIVER_TRIP_FEE_RECONCILE_LOOKBACK_HOURS;
    delete process.env.DRIVER_TRIP_FEE_RECONCILE_BATCH;
  });

  function makeTrip(overrides: Partial<TripEntity> = {}): TripEntity {
    return {
      id: 't1',
      driverId: 'd1',
      status: TripStatus.PUBLISHED,
      departureTime: new Date(Date.now() - 3 * 60 * 60 * 1000),
      driverWalletChargeApplied: false,
      ...overrides,
    } as TripEntity;
  }

  it('charges a trip whose auto-start job never fired', async () => {
    const trip = makeTrip();
    qb.getMany.mockResolvedValue([trip]);

    const result = await job.reconcileUnchargedTrips();

    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledWith(trip);
    expect(result).toMatchObject({ scanned: 1, recovered: 1, failed: 0 });
  });

  it('never charges a cancelled trip', async () => {
    await job.reconcileUnchargedTrips();

    expect(qb.andWhere).toHaveBeenCalledWith(
      expect.stringContaining('status'),
      expect.anything(),
    );
    expect(params.excludedStatuses).toContain(TripStatus.CANCELLED);
  });

  it('only looks at trips whose departure is past the grace window', async () => {
    process.env.DRIVER_TRIP_FEE_RECONCILE_GRACE_MINUTES = '90';
    const before = Date.now();

    await job.reconcileUnchargedTrips();

    const graceCutoff = params.graceCutoff as Date;
    expect(graceCutoff.getTime()).toBeLessThanOrEqual(
      before - 90 * 60 * 1000 + 5000,
    );
    expect(graceCutoff.getTime()).toBeGreaterThan(before - 91 * 60 * 1000);
  });

  it('does not reach back past the configured lookback window', async () => {
    process.env.DRIVER_TRIP_FEE_RECONCILE_LOOKBACK_HOURS = '48';
    const before = Date.now();

    await job.reconcileUnchargedTrips();

    const lookbackFloor = params.lookbackFloor as Date;
    expect(lookbackFloor.getTime()).toBeLessThanOrEqual(
      before - 48 * 60 * 60 * 1000 + 5000,
    );
  });

  it('keeps going when one trip throws, and reports the failure', async () => {
    qb.getMany.mockResolvedValue([
      makeTrip({ id: 'bad' }),
      makeTrip({ id: 'good' }),
    ]);
    driverTripFee.chargeAtTripStart
      .mockRejectedValueOnce(new Error('ledger down'))
      .mockResolvedValueOnce({
        tripId: 'good',
        charged: 1.6,
        pendingRemainder: 0,
        currency: 'JOD',
        applied: true,
      });

    const result = await job.reconcileUnchargedTrips();

    expect(driverTripFee.chargeAtTripStart).toHaveBeenCalledTimes(2);
    expect(result).toMatchObject({ scanned: 2, recovered: 1, failed: 1 });
  });

  it('does not count an already-charged short-circuit as a recovery', async () => {
    qb.getMany.mockResolvedValue([makeTrip()]);
    driverTripFee.chargeAtTripStart.mockResolvedValue({
      tripId: 't1',
      charged: 1.6,
      pendingRemainder: 0,
      currency: 'JOD',
      applied: false,
      reason: 'already-charged',
    });

    const result = await job.reconcileUnchargedTrips();

    expect(result).toMatchObject({ scanned: 1, recovered: 0, failed: 0 });
  });
});
