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
    it('reconciles a saved online state when the wallet is blocked', async () => {
      repo.findOne.mockResolvedValue({
        driverId: 'd1',
        isOnline: true,
        currentRequestId: 'active-ride',
        point: null,
      });
      wallet.assertNonNegativeDriverBalance.mockRejectedValue(
        new ForbiddenException({
          code: 'NEGATIVE_WALLET_BALANCE',
          message:
            'اشحن محفظتك بحد أدنى 5 دنانير أو 25 ريالاً أو ما يعادلها وسدد أي مستحقات للاستمرار في استقبال الرحلات وإنشائها.',
        }),
      );
      expect((await service.getStatus('d1')).isOnline).toBe(false);
      expect(repo.update).toHaveBeenCalledWith(
        { driverId: 'd1' },
        { isOnline: false },
      );
    });

    it('keeps a funded driver online', async () => {
      repo.findOne.mockResolvedValue({
        driverId: 'd1',
        isOnline: true,
        point: null,
      });
      expect((await service.getStatus('d1')).isOnline).toBe(true);
      expect(repo.update).not.toHaveBeenCalled();
    });

    it('reports offline in a heartbeat response when funds have run out', async () => {
      repo.findOne.mockResolvedValue({
        driverId: 'd1',
        isOnline: true,
        point: null,
      });
      wallet.assertNonNegativeDriverBalance.mockRejectedValue(
        new ForbiddenException('top up'),
      );
      expect((await service.heartbeat('d1', 31.9, 35.9)).isOnline).toBe(false);
    });

    it('preserves the wallet policy message when attempting to go online', async () => {
      users.findById.mockResolvedValue({ isDriverApproved: true });
      vehicles.findByDriver.mockResolvedValue({ id: 'v1', isVerified: true });
      const error = new ForbiddenException({
        code: 'NEGATIVE_WALLET_BALANCE',
        message:
          'اشحن محفظتك بحد أدنى 5 دنانير أو 25 ريالاً أو ما يعادلها وسدد أي مستحقات للاستمرار في استقبال الرحلات وإنشائها.',
      });
      wallet.assertNonNegativeDriverBalance.mockRejectedValue(error);
      await expect(
        service.setAvailability('d1', { isOnline: true }),
      ).rejects.toBe(error);
    });

    it('does not silently treat a database failure as an empty wallet', async () => {
      repo.findOne.mockResolvedValue({ driverId: 'd1', isOnline: true });
      wallet.assertNonNegativeDriverBalance.mockRejectedValue(
        new Error('database unavailable'),
      );
      await expect(service.getStatus('d1')).rejects.toThrow(
        'database unavailable',
      );
    });

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
