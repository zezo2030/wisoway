import { InstantDispatchService } from './instant-dispatch.service';

describe('InstantDispatchService.finalizeSearch', () => {
  let requestRepo: any;
  let offerRepo: any;
  let availabilityRepo: any;
  let availabilityService: any;
  let notifications: any;
  let offerQueue: any;
  let requestQueue: any;
  let service: InstantDispatchService;

  const request = {
    id: 'r1',
    passengerId: 'p1',
    status: 'searching',
  };

  beforeEach(() => {
    requestRepo = {
      findOne: jest.fn().mockResolvedValue(request),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    offerRepo = {
      find: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      save: jest.fn(),
      create: jest.fn(),
    };
    availabilityRepo = { update: jest.fn() };
    availabilityService = { findNearbyAvailableDrivers: jest.fn() };
    notifications = {
      sendPush: jest.fn().mockResolvedValue(undefined),
      getPreferredLocale: jest.fn().mockResolvedValue('ar'),
    };
    offerQueue = { add: jest.fn(), getJob: jest.fn() };
    requestQueue = { add: jest.fn(), getJob: jest.fn() };
    service = new InstantDispatchService(
      requestRepo,
      offerRepo,
      availabilityRepo,
      availabilityService,
      notifications,
      offerQueue,
      requestQueue,
    );
  });

  const terminalUpdate = () => requestRepo.update.mock.calls[0][1];

  it('records no_eligible_drivers when nobody was ever offered the ride', async () => {
    offerRepo.find.mockResolvedValue([]);

    const finalized = await service.finalizeSearch('r1');

    expect(finalized).toBe(true);
    expect(terminalUpdate()).toEqual(
      expect.objectContaining({
        status: 'expired',
        terminalReason: 'no_eligible_drivers',
        endedAt: expect.any(Date),
      }),
    );
  });

  it('records all_declined when every offer ended without an acceptance', async () => {
    offerRepo.find.mockResolvedValue([
      { status: 'declined' },
      { status: 'timed_out' },
    ]);

    await service.finalizeSearch('r1');

    expect(terminalUpdate().terminalReason).toBe('all_declined');
  });

  it('records ttl_expired when an offer was still outstanding', async () => {
    offerRepo.find.mockResolvedValue([
      { status: 'declined' },
      { status: 'countered' },
    ]);

    await service.finalizeSearch('r1');

    expect(terminalUpdate().terminalReason).toBe('ttl_expired');
  });

  it('honours a forced reason without inspecting offers', async () => {
    await service.finalizeSearch('r1', 'ttl_expired');

    expect(offerRepo.find).not.toHaveBeenCalled();
    expect(terminalUpdate().terminalReason).toBe('ttl_expired');
  });

  it('only claims the request once and skips notifying on a lost race', async () => {
    requestRepo.update.mockResolvedValue({ affected: 0 });

    const finalized = await service.finalizeSearch('r1');

    expect(finalized).toBe(false);
    expect(notifications.sendPush).not.toHaveBeenCalled();
  });

  it('notifies the passenger without leaking location data', async () => {
    await service.finalizeSearch('r1');

    const [passengerId, payload] = notifications.sendPush.mock.calls[0];
    expect(passengerId).toBe('p1');
    expect(payload.type).toBe('instant_no_drivers');
    expect(payload.data).toEqual({
      requestId: 'r1',
      terminalReason: 'no_eligible_drivers',
    });
  });
});

describe('InstantDispatchService.dispatchNext radius growth', () => {
  const TTL_MS = 180_000;

  /// Builds a service whose request was created `elapsedMs` ago.
  const setup = (elapsedMs: number) => {
    const now = Date.now();
    const request = {
      id: 'r1',
      passengerId: 'p1',
      status: 'searching',
      fareRevision: 0,
      radiusKm: 3,
      createdAt: new Date(now - elapsedMs),
      expiresAt: new Date(now - elapsedMs + TTL_MS),
      fromPoint: { type: 'Point', coordinates: [35.9, 31.9] },
    };
    const requestRepo: any = {
      findOne: jest.fn().mockResolvedValue(request),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    const availabilityService: any = {
      findNearbyAvailableDrivers: jest.fn().mockResolvedValue([]),
    };
    const service = new InstantDispatchService(
      requestRepo,
      { find: jest.fn().mockResolvedValue([]), count: jest.fn() } as any,
      { update: jest.fn() } as any,
      availabilityService,
      {
        sendPush: jest.fn().mockResolvedValue(undefined),
        getPreferredLocale: jest.fn().mockResolvedValue('ar'),
      } as any,
      { add: jest.fn().mockResolvedValue(undefined), getJob: jest.fn() } as any,
      { add: jest.fn().mockResolvedValue(undefined), getJob: jest.fn() } as any,
    );
    return { service, availabilityService };
  };

  /** Radius the lookup was actually run with, in km. */
  const searchedKm = (availabilityService: any) =>
    availabilityService.findNearbyAvailableDrivers.mock.calls[0][2] / 1000;

  it('searches close by at the very start of the window', async () => {
    const { service, availabilityService } = setup(0);

    await service.dispatchNext('r1');

    expect(searchedKm(availabilityService)).toBeCloseTo(3, 1);
  });

  it('widens as the passenger keeps waiting', async () => {
    const { service, availabilityService } = setup(TTL_MS / 2);

    await service.dispatchNext('r1');

    // Half the window elapsed -> half way between the initial and max reach.
    const km = searchedKm(availabilityService);
    expect(km).toBeGreaterThan(3);
    expect(km).toBeLessThan(25);
    expect(km).toBeCloseTo(3 + (25 - 3) / 2, 0);
  });

  it('reaches the configured ceiling by the end of the window', async () => {
    // Probed a second before expiry: at expiresAt itself the search finalises.
    const { service, availabilityService } = setup(TTL_MS - 1000);

    await service.dispatchNext('r1');

    expect(searchedKm(availabilityService)).toBeGreaterThan(24.5);
  });

  it('runs a single lookup per wave rather than one per ring', async () => {
    const { service, availabilityService } = setup(TTL_MS - 1000);

    await service.dispatchNext('r1');

    expect(
      availabilityService.findNearbyAvailableDrivers,
    ).toHaveBeenCalledTimes(1);
  });
});
