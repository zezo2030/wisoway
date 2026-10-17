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
  let ratings: { applyRatingPenalty: jest.Mock };
  let settings: { getNumber: jest.Mock };
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

  const lastPush = () =>
    notifications.sendPush.mock.calls[0] as [
      string,
      { type: string; title: string; body: string },
    ];

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
    ratings = { applyRatingPenalty: jest.fn().mockResolvedValue(undefined) };
    settings = { getNumber: jest.fn().mockResolvedValue(2) };
    queue = { add: jest.fn().mockResolvedValue(undefined) };
    service = new InstantPickupWatchService(
      tripRepo as never,
      requestRepo as never,
      notifications as never,
      ratings as never,
      settings as never,
      queue as never,
    );
  });

  it('first checks after the pickup estimate plus the grace, then repeats', () => {
    expect(pickupLateDelayMs(240, 1)).toBe(
      240_000 + PICKUP_LATE_GRACE_MINUTES * 60_000,
    );
    expect(pickupLateDelayMs(240, 2)).toBe(PICKUP_LATE_REMIND_MINUTES * 60_000);
  });

  it('tells a late driver to hurry, cuts the rating once, and reminds again', async () => {
    await service.check({ tripId: 't1', attempt: 1 });

    expect(ratings.applyRatingPenalty).toHaveBeenCalledWith('d1', 2);
    expect(requestRepo.update).toHaveBeenCalledWith(
      { id: 'r1' },
      expect.objectContaining({
        lateWarningCount: 1,
        ratingPenaltyPercent: '2.00',
      }),
    );
    const [driverId, push] = lastPush();
    expect(driverId).toBe('d1');
    expect(push.type).toBe('instant_pickup_late');
    expect(push.body).toContain('خُفِّض تقييمك 2%');
    expect(push.body).not.toContain('مخالفة');
    expect(queue.add).toHaveBeenCalledWith(
      'pickup-late-check',
      { tripId: 't1', attempt: 2 },
      expect.anything(),
    );
  });

  it('does not cut again on a later reminder of the same ride', async () => {
    requestRepo.findOne.mockResolvedValue({
      id: 'r1',
      lateWarningCount: 1,
      lateWarnedAt: new Date(),
      pickupEtaSeconds: 240,
    });

    await service.check({ tripId: 't1', attempt: 2 });

    expect(ratings.applyRatingPenalty).not.toHaveBeenCalled();
    expect(lastPush()[1].title).toBe('الراكب ما زال بانتظارك');
  });

  it('only warns when the admin set the cut to 0', async () => {
    settings.getNumber.mockResolvedValue(0);

    await service.check({ tripId: 't1', attempt: 1 });

    expect(ratings.applyRatingPenalty).not.toHaveBeenCalled();
    expect(lastPush()[1].body).not.toContain('تقييمك');
  });

  it('counts repeated lateness in the warning', async () => {
    requestRepo.count.mockResolvedValue(3);

    await service.check({ tripId: 't1', attempt: 1 });

    expect(lastPush()[1].body).toContain('رقم 3');
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
    expect(ratings.applyRatingPenalty).not.toHaveBeenCalled();
    expect(queue.add).not.toHaveBeenCalled();
  });

  it('speaks English to an English driver', () => {
    const text = lateWarningText('en', {
      lateRides: 1,
      firstWarning: true,
      penaltyPercent: 2,
    });
    expect(text.title).toBe('You are late for your passenger');
    expect(text.body).toContain('rating dropped 2%');
  });
});
