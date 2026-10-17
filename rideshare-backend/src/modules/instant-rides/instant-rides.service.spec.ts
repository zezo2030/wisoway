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
  let unpaidBooking: jest.Mock;
  let users: any;
  let vehicles: any;
  let locations: any;
  let notifications: any;
  let dispatch: any;
  let pickupWatch: any;
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
    unpaidBooking = jest.fn().mockResolvedValue(null);
    tripRepo = {
      manager: {
        getRepository: () => ({
          createQueryBuilder: () => {
            const qb: any = {};
            for (const m of [
              'innerJoin',
              'where',
              'andWhere',
              'orderBy',
              'select',
            ]) {
              qb[m] = () => qb;
            }
            qb.getOne = () => unpaidBooking();
            return qb;
          },
        }),
      },
    };
    users = {
      findById: jest.fn(),
      update: jest.fn().mockResolvedValue(undefined),
    };
    vehicles = { findById: jest.fn(), findByDriver: jest.fn() };
    locations = { getDistance: jest.fn(), reverseGeocode: jest.fn() };
    notifications = {
      sendPush: jest.fn().mockResolvedValue(undefined),
      emitRealtime: jest.fn(),
    };
    dispatch = { dispatchNext: jest.fn().mockResolvedValue(undefined) };
    pickupWatch = { schedule: jest.fn().mockResolvedValue(undefined) };
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
      pickupWatch,
      offerQueue,
      requestQueue,
    );
  });

  const dto: any = {
    from: { name: 'A', latitude: 31.9, longitude: 35.9 },
    to: { name: 'B', latitude: 31.8, longitude: 35.8 },
  };

  describe('createRequest', () => {
    it('rejects while the passenger is mid-ride', async () => {
      requestRepo.findOne.mockResolvedValue({ id: 'x', status: 'accepted' });
      await expect(service.createRequest('p1', dto)).rejects.toThrow(
        ConflictException,
      );
    });

    it('replaces a search the passenger walked away from', async () => {
      requestRepo.findOne.mockResolvedValue({ id: 'old', status: 'offered' });
      offerRepo.findOne.mockResolvedValue({
        id: 'o1',
        driverId: 'd1',
        status: 'offered',
      });
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'JO' });

      const view = await service.createRequest('p1', dto);

      expect(view.status).toBe('searching');
      // The stale search is cancelled and its driver told to stop ringing.
      expect(requestRepo.update).toHaveBeenCalledWith(
        { id: 'old' },
        expect.objectContaining({ status: 'cancelled' }),
      );
      expect(offerRepo.update).toHaveBeenCalledWith(
        { id: 'o1' },
        expect.objectContaining({ status: 'cancelled' }),
      );
      expect(notifications.emitRealtime).toHaveBeenCalledWith(
        'd1',
        'instantOfferClosed',
        expect.objectContaining({ offerId: 'o1' }),
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
      // JOD: 0.5 + 5*0.28 + 10*0.04 = 2.30, rounded up to the 0.25 step.
      expect(view.fareEstimate).toBe('2.50');
      expect(view.passengerFare).toBe('2.50');
      expect(view.maxFare).toBe('2.50');
      expect(dispatch.dispatchNext).toHaveBeenCalledWith('r1');
    });

    it("prices in the pickup country's tariff", async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockResolvedValue({
        distanceKm: 10,
        durationMinutes: 15,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'SA' });

      const view = await service.createRequest('p1', dto);

      expect(view.currency).toBe('SAR');
      // SAR: 6 + 10*1.4 + 15*0.3 = 24.5, rounded up to whole riyals.
      expect(view.fareEstimate).toBe('25.00');
    });

    it('ignores a fare typed by an older app — the platform sets it', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'JO' });

      const view = await service.createRequest('p1', {
        ...dto,
        passengerFare: 1.75,
      });

      expect(view.passengerFare).toBe('2.50');
    });

    it('uses the routed road distance when Google distance is unavailable', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockRejectedValue(new Error('REQUEST_DENIED'));
      locations.getRoute = jest.fn().mockResolvedValue({
        distanceMeters: 10_000,
        durationSeconds: 900,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'SA' });

      const view = await service.createRequest('p1', dto);

      expect(locations.getRoute).toHaveBeenCalled();
      expect(view.fareEstimate).toBe('25.00');
    });

    it('falls back to haversine + default currency when geocoding is unavailable', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockRejectedValue(new Error('no key'));
      locations.reverseGeocode.mockRejectedValue(new Error('no key'));

      const view = await service.createRequest('p1', dto);

      expect(view.currency).toBe('JOD');
      expect(Number(view.fareEstimate)).toBeGreaterThanOrEqual(1.5);
    });

    it("quotes in the passenger's phone currency when geocoding is unavailable", async () => {
      locations.getDistance.mockResolvedValue({
        distanceKm: 2.1,
        durationMinutes: 3,
      });
      locations.reverseGeocode.mockRejectedValue(new Error('REQUEST_DENIED'));
      users.findById.mockResolvedValue({
        id: 'p1',
        phoneNumber: '+966501234567',
      });

      const quote = await service.getQuote(dto, 'p1');

      expect(quote.currency).toBe('SAR');
      expect(quote.paymentMethods).not.toContain('cliq');
    });
  });

  describe('getActiveRide', () => {
    it('returns the in-progress instant trip the user is driving', async () => {
      tripRepo.findOne = jest.fn().mockResolvedValue({ id: 't1' });
      requestRepo.findOne.mockResolvedValue({ id: 'r1' });

      await expect(service.getActiveRide('d1')).resolves.toEqual({
        tripId: 't1',
        role: 'driver',
        requestId: 'r1',
        stage: 'ride',
      });
      expect(tripRepo.findOne).toHaveBeenCalledWith(
        expect.objectContaining({
          where: {
            driverId: 'd1',
            tripType: 'instant',
            status: 'in_progress',
          },
        }),
      );
    });

    it("returns the passenger's matched ride while its trip is live", async () => {
      tripRepo.findOne = jest
        .fn()
        .mockResolvedValueOnce(null) // not driving anything
        .mockResolvedValueOnce({ id: 't1', status: 'in_progress' });
      requestRepo.findOne.mockResolvedValue({
        id: 'r1',
        status: 'accepted',
        tripId: 't1',
      });

      await expect(service.getActiveRide('p1')).resolves.toEqual({
        tripId: 't1',
        role: 'passenger',
        requestId: 'r1',
        stage: 'ride',
      });
    });

    it('returns a finished ride whose fare is still open', async () => {
      tripRepo.findOne = jest
        .fn()
        .mockResolvedValueOnce(null) // not driving a live ride
        .mockResolvedValueOnce({ id: 't1', status: 'completed' });
      requestRepo.findOne.mockResolvedValue({
        id: 'r1',
        status: 'accepted',
        tripId: 't1',
      });
      unpaidBooking
        .mockResolvedValueOnce(null) // no cash fare waiting on this driver
        .mockResolvedValueOnce({ tripId: 't1' }); // the passenger owes one

      await expect(service.getActiveRide('p1')).resolves.toEqual({
        tripId: 't1',
        role: 'passenger',
        requestId: 'r1',
        stage: 'payment',
      });
    });
    it('returns null once the ride has finished', async () => {
      tripRepo.findOne = jest
        .fn()
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce({ id: 't1', status: 'completed' });
      requestRepo.findOne.mockResolvedValue({
        id: 'r1',
        status: 'accepted',
        tripId: 't1',
      });

      await expect(service.getActiveRide('p1')).resolves.toBeNull();
    });

    it('returns null while the passenger is still searching', async () => {
      tripRepo.findOne = jest.fn().mockResolvedValue(null);
      requestRepo.findOne.mockResolvedValue({ id: 'r1', status: 'searching' });

      await expect(service.getActiveRide('p1')).resolves.toBeNull();
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
      'starts a fresh search from a %s request, keeping route and seats',
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
        // Priced at the route's current fare (JOD 5 km / 10 min).
        expect(view.passengerFare).toBe('2.50');
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

    it('re-prices at the current fare instead of asking to reconfirm', async () => {
      requestRepo.findOne
        .mockResolvedValueOnce({ ...expiredRequest, passengerFare: '20.00' })
        .mockResolvedValueOnce(null);
      const manager = withManager();
      manager.findOne
        .mockResolvedValueOnce(expiredRequest)
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(null);

      const view = await service.retryRequest('r0', 'p1');

      expect(view.passengerFare).toBe('2.50');
      expect(dispatch.dispatchNext).toHaveBeenCalledWith('r2');
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

  describe('pickup stages', () => {
    const liveTrip = (over: any = {}) => ({
      id: 't1',
      driverId: 'd1',
      tripType: 'instant',
      status: 'in_progress',
      toName: 'B',
      driverArrivedAt: null,
      tripStartedAt: null,
      ...over,
    });

    beforeEach(() => {
      tripRepo.findOne = jest.fn();
      tripRepo.save = jest.fn().mockImplementation(async (t: any) => t);
      requestRepo.findOne.mockResolvedValue({ id: 'r1', passengerId: 'p1' });
    });

    it('records arrival once and tells the passenger', async () => {
      tripRepo.findOne.mockResolvedValue(liveTrip());

      const trip = await service.markArrivedAtPickup('t1', 'd1');

      expect(trip.driverArrivedAt).toBeInstanceOf(Date);
      expect(trip.tripStartedAt).toBeNull();
      expect(notifications.sendPush).toHaveBeenCalledWith(
        'p1',
        expect.objectContaining({ type: 'instant_driver_arrived' }),
      );
    });

    it('does not re-notify a repeated arrival', async () => {
      tripRepo.findOne.mockResolvedValue(
        liveTrip({ driverArrivedAt: new Date('2026-01-01') }),
      );

      await service.markArrivedAtPickup('t1', 'd1');

      expect(tripRepo.save).not.toHaveBeenCalled();
      expect(notifications.sendPush).not.toHaveBeenCalled();
    });

    it('starts the ride, implying arrival when it was skipped', async () => {
      tripRepo.findOne.mockResolvedValue(liveTrip());

      const trip = await service.startRide('t1', 'd1');

      expect(trip.tripStartedAt).toBeInstanceOf(Date);
      expect(trip.driverArrivedAt).toEqual(trip.tripStartedAt);
      expect(notifications.sendPush).toHaveBeenCalledWith(
        'p1',
        expect.objectContaining({ type: 'instant_ride_started' }),
      );
    });

    it("refuses another driver's ride", async () => {
      tripRepo.findOne.mockResolvedValue(liveTrip({ driverId: 'd2' }));
      await expect(service.startRide('t1', 'd1')).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('refuses a ride that already ended', async () => {
      tripRepo.findOne.mockResolvedValue(liveTrip({ status: 'completed' }));
      await expect(service.markArrivedAtPickup('t1', 'd1')).rejects.toThrow(
        ConflictException,
      );
    });
  });

  describe('driver cancels before pickup', () => {
    const accepted = {
      id: 'r1',
      passengerId: 'p1',
      status: 'accepted',
      tripId: 't1',
      fromName: 'A',
      toName: 'B',
      fromPoint: { type: 'Point', coordinates: [37.9, 26.6] },
      toPoint: { type: 'Point', coordinates: [37.95, 26.5] },
      seatCount: 1,
      paymentMethod: 'cash',
      acceptedFare: '15.00',
      passengerFare: '15.00',
      currency: 'SAR',
    };
    let m: any;

    beforeEach(() => {
      tripRepo.findOne = jest.fn().mockResolvedValue({
        id: 't1',
        driverId: 'd1',
        tripType: 'instant',
        status: 'in_progress',
        driverArrivedAt: null,
        tripStartedAt: null,
      });
      requestRepo.findOne.mockResolvedValue(accepted);
      m = {
        update: jest.fn().mockResolvedValue({ affected: 1 }),
        findOne: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation((_e: any, v: any) => v),
        save: jest.fn().mockImplementation(async (v: any) => ({
          fareRevision: 1,
          ...v,
          id: v.requestId ? 'o-x' : 'r2',
        })),
      };
      const run = (fn: any) => fn(m);
      tripRepo.manager.transaction = jest.fn().mockImplementation(run);
      requestRepo.manager.transaction = jest.fn().mockImplementation(run);
    });

    it('cancels the trip and booking and searches again at the same fare', async () => {
      const result = await service.cancelByDriver('t1', 'd1');

      expect(m.update).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ id: 't1', status: 'in_progress' }),
        { status: 'cancelled' },
      );
      expect(m.update).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ tripId: 't1', status: 'confirmed' }),
        expect.objectContaining({ status: 'cancelled', cancelledBy: 'd1' }),
      );
      expect(m.update).toHaveBeenCalledWith(
        expect.anything(),
        { id: 'r1' },
        expect.objectContaining({
          status: 'cancelled',
          terminalReason: 'driver_cancelled',
        }),
      );
      // Same route and agreed fare, searching again.
      expect(m.save).toHaveBeenCalledWith(
        expect.objectContaining({
          retryOfRequestId: 'r1',
          status: 'searching',
          passengerFare: '15.00',
          currency: 'SAR',
        }),
      );
      // The cancelling driver is never offered the new search.
      expect(m.save).toHaveBeenCalledWith(
        expect.objectContaining({
          requestId: 'r2',
          driverId: 'd1',
          status: 'cancelled',
        }),
      );
      expect(availabilityRepo.update).toHaveBeenCalledWith(
        { driverId: 'd1', currentRequestId: 'r1' },
        { currentRequestId: null },
      );
      expect(dispatch.dispatchNext).toHaveBeenCalledWith('r2');
      expect(notifications.sendPush).toHaveBeenCalledWith(
        'p1',
        expect.objectContaining({
          type: 'instant_driver_cancelled',
          data: expect.objectContaining({ requestId: 'r2', searching: true }),
        }),
      );
      expect(result).toEqual({ cancelled: true, nextRequestId: 'r2' });
    });

    it('refuses once the passenger is on board', async () => {
      tripRepo.findOne.mockResolvedValue({
        id: 't1',
        driverId: 'd1',
        tripType: 'instant',
        status: 'in_progress',
        tripStartedAt: new Date(),
      });

      await expect(service.cancelByDriver('t1', 'd1')).rejects.toThrow(
        ConflictException,
      );
      expect(tripRepo.manager.transaction).not.toHaveBeenCalled();
    });

    it("refuses another driver's ride", async () => {
      await expect(service.cancelByDriver('t1', 'd2')).rejects.toThrow(
        ForbiddenException,
      );
    });
  });
  describe('payment method', () => {
    it('refuses CliQ outside Jordan', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'SA' });

      await expect(
        service.createRequest('p1', { ...dto, paymentMethod: 'cliq' }),
      ).rejects.toThrow('CliQ');
    });

    it('stores CliQ on a Jordanian request', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'JO' });

      const view = await service.createRequest('p1', {
        ...dto,
        paymentMethod: 'cliq',
        payerCliqAlias: '0791234567',
      });

      expect(view.paymentMethod).toBe('cliq');
      // Normalized for uWallet and remembered for next time.
      expect(requestRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ payerCliqAlias: '00962791234567' }),
      );
      expect(users.update).toHaveBeenCalledWith('p1', {
        cliqAlias: '00962791234567',
      });
    });

    it('asks for a CliQ alias when there is none on file', async () => {
      requestRepo.findOne.mockResolvedValue(null);
      locations.getDistance.mockResolvedValue({
        distanceKm: 5,
        durationMinutes: 10,
      });
      locations.reverseGeocode.mockResolvedValue({ countryCode: 'JO' });

      await expect(
        service.createRequest('p1', { ...dto, paymentMethod: 'cliq' }),
      ).rejects.toThrow('CliQ');
    });
  });
});
