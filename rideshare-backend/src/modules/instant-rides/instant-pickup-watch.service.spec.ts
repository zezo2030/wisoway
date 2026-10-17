import {
  InstantPickupWatchService,
  lateWarningText,
} from './instant-pickup-watch.service';
import {
  PICKUP_LATE_GRACE_MINUTES,
  PICKUP_LATE_MAX_WARNINGS,
  PICKUP_LATE_REMIND_MINUTES,
  pickupLateDelayMs,
} from './instant-rides.constants';

describe('InstantPickupWatchService', () => {
  let tripRepo: { findOne: jest.Mock };
  let requestRepo: { findOne: jest.Mock; update: jest.Mock; count: jest.Mock };
  let notifications: {
    sendPush: jest.Mock;
    emitRealtime: jest.Mock;
    getPreferredLocale: jest.Mock;
  };
  let queue: { add: jest.Mock };
  let service: InstantPickupWatchService;

  const liveTrip = (over: Record<string, unknown> = {}) => ({
    id: 't1',
    driverId: 'd1',
    tripType: 'instant',
    status: 'in_progress',
    driverArrivedAt: null,
    tripStartedAt: null,
    ...over,
  });

  beforeEach(() => {
    tripRepo = { findOne: jest.fn().mockResolvedValue(liveTrip()) };
    requestRepo = {
      findOne: jest.fn().mockResolvedValue({
        id: 'r1',
        lateWarningCount: 0,
        lateWarnedAt: null,
        pickupEtaSeconds: 240,
      }),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      count: jest.fn().mockResolvedValue(1),
    };
    notifications = {
      sendPush: jest.fn().mockResolvedValue(undefined),
      emitRealtime: jest.fn(),
      getPreferredLocale: jest.fn().mockResolvedValue('ar'),
    };
    queue = { add: jest.fn().mockResolvedValue(undefined) };
    service = new InstantPickupWatchService(
      tripRepo as never,
      requestRepo as never,
      notifications as never,
      queue as never,
    );
  });

  it('first checks after the pickup estimate plus the grace, then repeats', () => {
    expect(pickupLateDelayMs(240, 1)).toBe(
      240_000 + PICKUP_LATE_GRACE_MINUTES * 60_000,
    );
    expect(pickupLateDelayMs(240, 2)).toBe(PICKUP_LATE_REMIND_MINUTES * 60_000);
  });

  it('tells a late driver to hurry, warns of a fine, and reminds again', async () => {
    await service.check({ tripId: 't1', attempt: 1 });

    expect(requestRepo.update).toHaveBeenCalledWith(
      { id: 'r1' },
      expect.objectContaining({ lateWarningCount: 1 }),
    );
    const [driverId, push] = notifications.sendPush.mock.calls[0] as [
      string,
      { type: string; body: string },
    ];
    expect(driverId).toBe('d1');
    expect(push.type).toBe('instant_pickup_late');
    expect(push.body).toContain('مخالفة');
    expect(queue.add).toHaveBeenCalledWith(
      'pickup-late-check',
      { tripId: 't1', attempt: 2 },
      expect.anything(),
    );
  });

  it('counts repeated lateness in the warning', async () => {
    requestRepo.count.mockResolvedValue(3);

    await service.check({ tripId: 't1', attempt: 1 });

    const [, push] = notifications.sendPush.mock.calls[0] as [
      string,
      { body: string },
    ];
    expect(push.body).toContain('رقم 3');
  });

  it('stops reminding after the last warning', async () => {
    await service.check({ tripId: 't1', attempt: PICKUP_LATE_MAX_WARNINGS });

    expect(notifications.sendPush).toHaveBeenCalled();
    expect(queue.add).not.toHaveBeenCalled();
  });

  it.each([
    ['arrived', { driverArrivedAt: new Date() }],
    ['started', { tripStartedAt: new Date() }],
    ['cancelled', { status: 'cancelled' }],
  ])('stays quiet once the driver %s', async (_label, over) => {
    tripRepo.findOne.mockResolvedValue(liveTrip(over));

    await service.check({ tripId: 't1', attempt: 1 });

    expect(notifications.sendPush).not.toHaveBeenCalled();
    expect(requestRepo.update).not.toHaveBeenCalled();
    expect(queue.add).not.toHaveBeenCalled();
  });

  it('speaks English to an English driver', () => {
    expect(lateWarningText('en', 1).title).toBe(
      'You are late for your passenger',
    );
  });
});
