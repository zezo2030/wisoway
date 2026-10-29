import { InstantDispatchService } from './instant-dispatch.service';
import {
  INITIAL_RADIUS_KM,
  MAX_RADIUS_KM,
  NO_DRIVER_SEARCH_SECONDS,
  OFFER_TTL_SECONDS,
  REQUEST_TTL_SECONDS,
  offerTtlSeconds,
} from './instant-rides.constants';

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
      emitRealtime: jest.fn(),
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
  const TTL_MS = REQUEST_TTL_SECONDS * 1000;
  /** The reach grows over the no-driver window, not the whole TTL. */
  const WINDOW_MS = NO_DRIVER_SEARCH_SECONDS * 1000;

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
    const requestQueue: any = {
      add: jest.fn().mockResolvedValue(undefined),
      getJob: jest.fn(),
    };
    const service = new InstantDispatchService(
      requestRepo,
      { find: jest.fn().mockResolvedValue([]), count: jest.fn() } as any,
      { update: jest.fn() } as any,
      availabilityService,
      {
        sendPush: jest.fn().mockResolvedValue(undefined),
        emitRealtime: jest.fn(),
        getPreferredLocale: jest.fn().mockResolvedValue('ar'),
      } as any,
      { add: jest.fn().mockResolvedValue(undefined), getJob: jest.fn() } as any,
      requestQueue,
    );
    return { service, availabilityService, requestRepo, requestQueue };
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
    const { service, availabilityService } = setup(WINDOW_MS / 2);

    await service.dispatchNext('r1');

    // Half the window elapsed -> half way between the initial and max reach.
    const km = searchedKm(availabilityService);
    expect(km).toBeGreaterThan(INITIAL_RADIUS_KM);
    expect(km).toBeLessThan(MAX_RADIUS_KM);
    expect(km).toBeCloseTo(
      INITIAL_RADIUS_KM + (MAX_RADIUS_KM - INITIAL_RADIUS_KM) / 2,
      0,
    );
  });

  it('reaches the configured ceiling (20 km by default) by the end of the window', async () => {
    const { service, availabilityService } = setup(WINDOW_MS - 100);

    await service.dispatchNext('r1');

    expect(searchedKm(availabilityService)).toBeGreaterThan(
      MAX_RADIUS_KM - 0.5,
    );
    expect(searchedKm(availabilityService)).toBeLessThanOrEqual(MAX_RADIUS_KM);
  });

  it('runs a single lookup per wave rather than one per ring', async () => {
    const { service, availabilityService } = setup(WINDOW_MS - 1000);

    await service.dispatchNext('r1');

    expect(
      availabilityService.findNearbyAvailableDrivers,
    ).toHaveBeenCalledTimes(1);
  });

  it('keeps searching while the reach is still growing', async () => {
    const { service, requestRepo, requestQueue } = setup(WINDOW_MS / 2);

    await service.dispatchNext('r1');

    expect(requestQueue.add).toHaveBeenCalledWith(
      'dispatch-wave',
      { requestId: 'r1' },
      expect.anything(),
    );
    expect(requestRepo.update).not.toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ status: 'expired' }),
    );
  });

  it('ends the search once the full reach found nobody', async () => {
    const { service, requestRepo, requestQueue } = setup(WINDOW_MS + 100);

    await service.dispatchNext('r1');

    // Told «لا يوجد سائق» now, not at the request TTL.
    expect(requestRepo.update).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'r1' }),
      expect.objectContaining({
        status: 'expired',
        terminalReason: 'no_eligible_drivers',
      }),
    );
    expect(requestQueue.add).not.toHaveBeenCalled();
  });
});

describe('instant search length', () => {
  it('caps the whole search at 60 seconds by default', () => {
    expect(REQUEST_TTL_SECONDS).toBe(60);
    expect(NO_DRIVER_SEARCH_SECONDS).toBeLessThanOrEqual(REQUEST_TTL_SECONDS);
  });

  it('never lets an offer outlive the request', () => {
    expect(offerTtlSeconds(120_000)).toBe(OFFER_TTL_SECONDS);
    expect(offerTtlSeconds(30_000)).toBe(30);
    expect(offerTtlSeconds(24_400)).toBe(24);
  });

  it('sends no offer a driver could not answer in time', () => {
    expect(offerTtlSeconds(19_900)).toBe(0);
    expect(offerTtlSeconds(-1_000)).toBe(0);
  });

  it('ends the search instead of offering with seconds to spare', async () => {
    const now = Date.now();
    const request = {
      id: 'r1',
      passengerId: 'p1',
      status: 'searching',
      fareRevision: 0,
      radiusKm: 20,
      createdAt: new Date(now - 25_000),
      expiresAt: new Date(now + 5_000),
      fromPoint: { type: 'Point', coordinates: [35.9, 31.9] },
    };
    const requestRepo: any = {
      findOne: jest.fn().mockResolvedValue(request),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    const availabilityService: any = {
      findNearbyAvailableDrivers: jest.fn(),
    };
    const service = new InstantDispatchService(
      requestRepo,
      { find: jest.fn().mockResolvedValue([]), count: jest.fn() } as any,
      { update: jest.fn() } as any,
      availabilityService,
      {
        sendPush: jest.fn().mockResolvedValue(undefined),
        emitRealtime: jest.fn(),
        getPreferredLocale: jest.fn().mockResolvedValue('ar'),
      } as any,
      { add: jest.fn(), getJob: jest.fn() } as any,
      { add: jest.fn(), getJob: jest.fn() } as any,
    );

    await service.dispatchNext('r1');

    expect(
      availabilityService.findNearbyAvailableDrivers,
    ).not.toHaveBeenCalled();
    expect(requestRepo.update).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'r1' }),
      expect.objectContaining({ status: 'expired' }),
    );
  });
});
