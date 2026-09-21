import { ForbiddenException } from '@nestjs/common';
import { DriverAvailabilityService } from './driver-availability.service';

describe('DriverAvailabilityService', () => {
  let repo: any;
  let vehicles: any;
  let users: any;
  let wallet: any;
  let service: DriverAvailabilityService;

  beforeEach(() => {
    repo = {
      findOne: jest.fn(),
      update: jest.fn().mockResolvedValue({ affected: 1 }),
      save: jest.fn().mockResolvedValue(undefined),
      merge: jest.fn().mockImplementation((a: any, b: any) => ({ ...a, ...b })),
      create: jest.fn().mockImplementation((v: any) => v),
    };
    vehicles = { findByDriver: jest.fn() };
    users = { findById: jest.fn() };
    wallet = {
      assertNonNegativeDriverBalance: jest.fn().mockResolvedValue(undefined),
    };
    service = new DriverAvailabilityService(repo, vehicles, users, wallet);
  });

  describe('setAvailability (going online)', () => {
    it('rejects when the driver is not approved', async () => {
      users.findById.mockResolvedValue({ isDriverApproved: false });
      await expect(
        service.setAvailability('d1', { isOnline: true }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects when the driver has no vehicle', async () => {
      users.findById.mockResolvedValue({ isDriverApproved: true });
      vehicles.findByDriver.mockResolvedValue(null);
      await expect(
        service.setAvailability('d1', { isOnline: true }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('rejects when the vehicle is not verified', async () => {
      users.findById.mockResolvedValue({ isDriverApproved: true });
      vehicles.findByDriver.mockResolvedValue({ id: 'v1', isVerified: false });
      await expect(
        service.setAvailability('d1', { isOnline: true }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('goes online when approved with a verified vehicle', async () => {
      users.findById.mockResolvedValue({ isDriverApproved: true });
      vehicles.findByDriver.mockResolvedValue({ id: 'v1', isVerified: true });
      repo.findOne
        .mockResolvedValueOnce(null) // upsert: no existing row
        .mockResolvedValueOnce({
          driverId: 'd1',
          isOnline: true,
          acceptsInstant: true,
          vehicleId: 'v1',
          point: null,
          lastSeenAt: new Date(),
        }); // getStatus

      const status = await service.setAvailability('d1', {
        isOnline: true,
        latitude: 31.9,
        longitude: 35.9,
      });

      expect(status.isOnline).toBe(true);
      expect(status.vehicleId).toBe('v1');
      expect(repo.save).toHaveBeenCalled();
    });
  });

  describe('heartbeat', () => {
    it('rejects when the driver is offline', async () => {
      repo.findOne.mockResolvedValue({ driverId: 'd1', isOnline: false });
      await expect(service.heartbeat('d1', 31.9, 35.9)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('getStatus', () => {
    it('returns an offline default when there is no row', async () => {
      repo.findOne.mockResolvedValue(null);
      const status = await service.getStatus('d1');
      expect(status.isOnline).toBe(false);
      expect(status.driverId).toBe('d1');
    });
  });

  describe('findNearbyDriverPins', () => {
    it('returns anonymous coordinates rounded to ~110 m', async () => {
      const qb: any = {
        select: jest.fn().mockReturnThis(),
        addSelect: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        orderBy: jest.fn().mockReturnThis(),
        limit: jest.fn().mockReturnThis(),
        getRawMany: jest.fn().mockResolvedValue([
          { lat: '31.958731', lng: '35.912264' },
          { lat: 31.951112, lng: 35.90995 },
        ]),
      };
      repo.createQueryBuilder = jest.fn().mockReturnValue(qb);

      const pins = await service.findNearbyDriverPins(31.95, 35.91);

      expect(pins).toEqual([
        { latitude: 31.959, longitude: 35.912 },
        { latitude: 31.951, longitude: 35.91 },
      ]);
      // Nothing that could identify the driver leaves the service.
      for (const pin of pins) {
        expect(Object.keys(pin).sort()).toEqual(['latitude', 'longitude']);
      }
    });
  });
});
