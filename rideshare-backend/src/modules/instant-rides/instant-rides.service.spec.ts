import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { InstantRidesService } from './instant-rides.service';

describe('InstantRidesService', () => {
  let requestRepo: any;
  let offerRepo: any;
  let availabilityRepo: any;
  let tripRepo: any;
  let users: any;
  let vehicles: any;
  let locations: any;
  let notifications: any;
  let dispatch: any;
  let offerQueue: any;
  let requestQueue: any;
  let service: InstantRidesService;

  beforeEach(() => {
    requestRepo = {
      findOne: jest.fn(),
      create: jest.fn().mockImplementation((v: any) => v),
      save: jest
        .fn()
        .mockImplementation(async (v: any) => ({ ...v, id: 'r1' })),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      manager: { transaction: jest.fn() },
    };
    offerRepo = {
      findOne: jest.fn(),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
    };
    availabilityRepo = { update: jest.fn().mockResolvedValue({ affected: 1 }) };
    tripRepo = {};
    users = { findById: jest.fn() };
    vehicles = { findById: jest.fn(), findByDriver: jest.fn() };
    locations = { getDistance: jest.fn(), reverseGeocode: jest.fn() };
    notifications = { sendPush: jest.fn().mockResolvedValue(undefined) };
    dispatch = { dispatchNext: jest.fn().mockResolvedValue(undefined) };
    offerQueue = {
      add: jest.fn().mockResolvedValue(undefined),
      getJob: jest.fn().mockResolvedValue(null),
    };
    requestQueue = {
      add: jest.fn().mockResolvedValue(undefined),
      getJob: jest.fn().mockResolvedValue(null),
    };
    service = new InstantRidesService(
      requestRepo,
      offerRepo,
      availabilityRepo,
      tripRepo,
      users,
      vehicles,
      locations,
      notifications,
      dispatch,
      offerQueue,
      requestQueue,
    );
  });

  const dto: any = {
    from: { name: 'A', latitude: 31.9, longitude: 35.9 },
    to: { name: 'B', latitude: 31.8, longitude: 35.8 },
  };

  describe('createRequest', () => {
    it('rejects when an active request already exists', async () => {
      requestRepo.findOne.mockResolvedValue({ id: 'x', status: 'searching' });
      await expect(service.createRequest('p1', dto)).rejects.toThrow(
        ConflictException,
      );
    });

    it('creates a searching request with a fare and pickup-country currency', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'JO' });

      const view = await service.createRequest('p1', dto);

      expect(view.status).toBe('searching');
      expect(view.currency).toBe('JOD');
      // 1 (base) + 5*0.5 (per km) + 10*0.1 (per min) = 4.50
      expect(view.fareEstimate).toBe('4.50');
      expect(dispatch.dispatchNext).toHaveBeenCalledWith('r1');
    });

    it('falls back to haversine + default currency when geocoding is unavailable', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockRejectedValue(new Error('no key'));
      locations.reverseGeocode.mockRejectedValue(new Error('no key'));

      const view = await service.createRequest('p1', dto);

      expect(view.currency).toBe('JOD');
      expect(Number(view.fareEstimate)).toBeGreaterThanOrEqual(1.5);
    });
  });

  describe('retryRequest', () => {
    const expiredRequest = {
      id: 'r0',
      passengerId: 'p1',
      status: 'expired',
      fromName: 'A',
      fromAddress: null,
      fromPoint: { type: 'Point', coordinates: [35.9, 31.9] },
      toName: 'B',
      toAddress: null,
      toPoint: { type: 'Point', coordinates: [35.8, 31.8] },
      seatCount: 2,
      fareEstimate: '4.50',
      passengerFare: '4.50',
      recommendedFare: '4.50',
      currency: 'JOD',
    };

    /** Fake entity manager driving the retry transaction. */
    function withManager(overrides: Partial<Record<string, any>> = {}) {
      const manager = {
        findOne: jest.fn(),
        create: jest.fn().mockImplementation((_e: any, v: any) => v),
        save: jest
          .fn()
          .mockImplementation(async (v: any) => ({ ...v, id: 'r2' })),
        ...overrides,
      };
      requestRepo.manager.transaction.mockImplementation(async (cb: any) =>
        cb(manager),
      );
      return manager;
    }

    beforeEach(() => {
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'JO' });
    });

    it('rejects a request that belongs to someone else', async () => {
      requestRepo.findOne.mockResolvedValue(expiredRequest);
      await expect(service.retryRequest('r0', 'other')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('rejects a request that is not found', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      await expect(service.retryRequest('r0', 'p1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it.each(['searching', 'offered', 'accepted', 'cancelled'])(
      'rejects a %s request as not retryable',
      async (status) => {
        requestRepo.findOne.mockResolvedValue({ ...expiredRequest, status });
        await expect(service.retryRequest('r0', 'p1')).rejects.toMatchObject({
          response: { code: 'INSTANT_REQUEST_NOT_RETRYABLE' },
        });
      },
    );

    it.each(['expired', 'no_drivers'])(
      'starts a fresh search from a %s request, keeping route, seats and fare',
      async (status) => {
        requestRepo.findOne
          .mockResolvedValueOnce({ ...expiredRequest, status }) // original
          .mockResolvedValueOnce(null); // no retry yet
        const manager = withManager();
        manager.findOne
          .mockResolvedValueOnce({ ...expiredRequest, status }) // locked row
          .mockResolvedValueOnce(null) // no existing child
          .mockResolvedValueOnce(null); // no active request

        const view = await service.retryRequest('r0', 'p1');

        expect(view.id).toBe('r2');
        expect(view.status).toBe('searching');
        expect(view.retryOfRequestId).toBe('r0');
        expect(view.seatCount).toBe(2);
        expect(view.passengerFare).toBe('4.50');
        expect(dispatch.dispatchNext).toHaveBeenCalledWith('r2');
        expect(requestQueue.add).toHaveBeenCalled();
      },
    );

    it('returns the existing attempt on a double tap instead of a third request', async () => {
      requestRepo.findOne
        .mockResolvedValueOnce(expiredRequest)
        .mockResolvedValueOnce({
          ...expiredRequest,
          id: 'r2',
          status: 'searching',
          retryOfRequestId: 'r0',
        });

      const view = await service.retryRequest('r0', 'p1');

      expect(view.id).toBe('r2');
      expect(requestRepo.manager.transaction).not.toHaveBeenCalled();
      expect(dispatch.dispatchNext).not.toHaveBeenCalled();
    });

    it('returns the winner when a concurrent tap created the retry mid-transaction', async () => {
      requestRepo.findOne
        .mockResolvedValueOnce(expiredRequest)
        .mockResolvedValueOnce(null);
      const manager = withManager();
      manager.findOne
        .mockResolvedValueOnce(expiredRequest)
        .mockResolvedValueOnce({
          ...expiredRequest,
          id: 'r2',
          status: 'searching',
          retryOfRequestId: 'r0',
        });

      const view = await service.retryRequest('r0', 'p1');

      expect(view.id).toBe('r2');
      expect(manager.save).not.toHaveBeenCalled();
      expect(dispatch.dispatchNext).not.toHaveBeenCalled();
    });

    it('refuses to create a second live request for the passenger', async () => {
      requestRepo.findOne
        .mockResolvedValueOnce(expiredRequest)
        .mockResolvedValueOnce(null);
      const manager = withManager();
      manager.findOne
        .mockResolvedValueOnce(expiredRequest)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({ id: 'r9', status: 'searching' });

      await expect(service.retryRequest('r0', 'p1')).rejects.toMatchObject({
        response: { code: 'INSTANT_ACTIVE_REQUEST_EXISTS' },
      });
      expect(manager.save).not.toHaveBeenCalled();
    });

    it('asks for fare re-confirmation instead of re-pricing silently', async () => {
      requestRepo.findOne
        .mockResolvedValueOnce({ ...expiredRequest, passengerFare: '20.00' })
        .mockResolvedValueOnce(null);
      const manager = withManager();

      await expect(service.retryRequest('r0', 'p1')).rejects.toMatchObject({
        response: {
          code: 'INSTANT_RETRY_FARE_RECONFIRMATION_REQUIRED',
          quote: expect.objectContaining({
            recommendedFare: '4.50',
            maxFare: '9.00',
            currency: 'JOD',
          }),
        },
      });
      expect(manager.save).not.toHaveBeenCalled();
      expect(dispatch.dispatchNext).not.toHaveBeenCalled();
    });
  });

  describe('request view', () => {
    it('marks an exhausted search retryable and exposes its terminal reason', async () => {
      requestRepo.findOne.mockResolvedValue({
        id: 'r1',
        passengerId: 'p1',
        status: 'expired',
        terminalReason: 'all_declined',
        retryOfRequestId: null,
        currency: 'JOD',
        seatCount: 1,
      });

      const view = await service.getRequest('r1', 'p1');

      expect(view).toEqual(
        expect.objectContaining({
          status: 'expired',
          terminalReason: 'all_declined',
          canRetry: true,
          retryOfRequestId: null,
        }),
      );
    });

    it.each(['searching', 'accepted', 'cancelled'])(
      'does not offer retry for a %s request',
      async (status) => {
        requestRepo.findOne.mockResolvedValue({
          id: 'r1',
          passengerId: 'p1',
          status,
          currency: 'JOD',
          seatCount: 1,
        });

        const view = await service.getRequest('r1', 'p1');

        expect(view.canRetry).toBe(false);
      },
    );
  });

  describe('offer responses', () => {
    it('acceptOffer throws when the offer is not found', async () => {
      offerRepo.findOne.mockResolvedValue(null);
      await expect(service.acceptOffer('o1', 'd1')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('acceptOffer throws when the offer is no longer OFFERED', async () => {
      offerRepo.findOne.mockResolvedValue({
        id: 'o1',
        driverId: 'd1',
        status: 'declined',
      });
      await expect(service.acceptOffer('o1', 'd1')).rejects.toThrow(
        ConflictException,
      );
    });

    it('declineOffer frees the driver and re-dispatches', async () => {
      offerRepo.findOne.mockResolvedValue({
        id: 'o1',
        driverId: 'd1',
        requestId: 'r1',
        status: 'offered',
      });

      const result = await service.declineOffer('o1', 'd1');

      expect(result).toEqual({ ok: true });
      expect(availabilityRepo.update).toHaveBeenCalled();
      expect(dispatch.dispatchNext).toHaveBeenCalledWith('r1');
    });
  });
});
