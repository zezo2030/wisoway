import { ConflictException, NotFoundException } from '@nestjs/common';
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
