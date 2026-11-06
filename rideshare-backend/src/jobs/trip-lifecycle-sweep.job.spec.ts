import type { Queue } from 'bull';
import type { Repository } from 'typeorm';
import type { TripEntity } from '../database/entities/trip.entity';
import { TripLifecycleSweepJob } from './trip-lifecycle-sweep.job';

type QueueMock = { getJob: jest.Mock; add: jest.Mock };

describe('TripLifecycleSweepJob', () => {
  let find: jest.Mock;
  let startQueue: QueueMock;
  let completeQueue: QueueMock;
  let job: TripLifecycleSweepJob;

  const now = new Date('2026-10-16T10:00:00Z');

  const point = { coordinates: [35.9, 31.9] };
  const overdueTrip = {
    id: 't2',
    departureTime: new Date('2026-10-16T09:00:00Z'),
    tripStartedAt: new Date('2026-10-16T09:00:00Z'),
    fromPoint: point,
    toPoint: point,
  };

  const makeQueue = (): QueueMock => ({
    getJob: jest.fn().mockResolvedValue(null),
    add: jest.fn().mockResolvedValue({}),
  });

  beforeEach(() => {
    find = jest
      .fn()
      // overdue starts, then overdue completes
      .mockResolvedValueOnce([{ id: 't1' }])
      .mockResolvedValueOnce([overdueTrip]);
    startQueue = makeQueue();
    completeQueue = makeQueue();
    job = new TripLifecycleSweepJob(
      { find } as unknown as Repository<TripEntity>,
      startQueue as unknown as Queue,
      completeQueue as unknown as Queue,
    );
  });

  it('re-queues lost start and complete jobs for shared trips past their time', async () => {
    await expect(job.sweep(now)).resolves.toBe(2);

    expect(find).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        where: expect.objectContaining({ tripType: 'scheduled' }) as unknown,
      }),
    );
    expect(startQueue.add).toHaveBeenCalledWith(
      'enforce',
      { tripId: 't1' },
      expect.objectContaining({ jobId: 'trip-auto-start-t1' }),
    );
    expect(completeQueue.add).toHaveBeenCalledWith(
      'enforce',
      { tripId: 't2' },
      expect.objectContaining({ jobId: 'trip-auto-complete-t2' }),
    );
  });

  it('retries a failed job instead of adding a duplicate', async () => {
    const retry = jest.fn().mockResolvedValue(undefined);
    startQueue.getJob.mockResolvedValue({
      getState: jest.fn().mockResolvedValue('failed'),
      retry,
    });

    await job.sweep(now);

    expect(retry).toHaveBeenCalled();
    expect(startQueue.add).not.toHaveBeenCalled();
  });

  it('leaves a job that is already running alone', async () => {
    startQueue.getJob.mockResolvedValue({
      getState: jest.fn().mockResolvedValue('active'),
    });

    await expect(job.sweep(now)).resolves.toBe(1);

    expect(startQueue.add).not.toHaveBeenCalled();
  });

  it('brings forward a job delayed past the time the trip is due', async () => {
    const promote = jest.fn().mockResolvedValue(undefined);
    completeQueue.getJob.mockResolvedValue({
      getState: jest.fn().mockResolvedValue('delayed'),
      promote,
    });

    await job.sweep(now);

    expect(promote).toHaveBeenCalled();
    expect(completeQueue.add).not.toHaveBeenCalled();
  });

  it('leaves a trip that is not due yet', async () => {
    find.mockReset();
    find
      .mockResolvedValueOnce([])
      .mockResolvedValueOnce([
        { ...overdueTrip, tripStartedAt: new Date('2026-10-16T09:50:00Z') },
      ]);

    await expect(job.sweep(now)).resolves.toBe(0);

    expect(completeQueue.add).not.toHaveBeenCalled();
  });
});
