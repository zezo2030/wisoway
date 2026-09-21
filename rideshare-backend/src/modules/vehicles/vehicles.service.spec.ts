import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { VehiclesService } from './vehicles.service';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { countSeatsInLayout, resolveVehicleTypeTemplate } from './vehicle-types';

describe('VehiclesService', () => {
  let service: VehiclesService;
  let vehicleRepo: {
    findOne: jest.Mock;
    create: jest.Mock;
    save: jest.Mock;
    merge: jest.Mock;
    remove: jest.Mock;
  };

  const driverId = 'driver-1';
  const otherDriverId = 'driver-2';
  const vehicleId = 'vehicle-1';

  const mockVehicle = (): VehicleEntity =>
    ({
      id: vehicleId,
      driverId,
      vehicleType: 'sedan',
      plateNumber: 'ABC-123',
      model: 'Toyota Camry',
      seats: 4,
      isVerified: false,
    }) as VehicleEntity;

  beforeEach(async () => {
    vehicleRepo = {
      findOne: jest.fn(),
      create: jest.fn((data) => data),
      save: jest.fn(async (entity) => entity),
      merge: jest.fn((target, patch) => Object.assign(target, patch)),
      remove: jest.fn(async (entity) => entity),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehiclesService,
        {
          provide: getRepositoryToken(VehicleEntity),
          useValue: vehicleRepo,
        },
      ],
    }).compile();

    service = module.get<VehiclesService>(VehiclesService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    const dto = {
      vehicleType: 'sedan',
      plateNumber: 'ABC-123',
      model: 'Toyota Camry',
    } as CreateVehicleDto;

    it('creates a vehicle for a driver who has none', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);

      const result = await service.create(dto, driverId);

      expect(vehicleRepo.findOne).toHaveBeenCalledWith({ where: { driverId } });
      expect(vehicleRepo.save).toHaveBeenCalledTimes(1);
      expect(result).toEqual(expect.objectContaining({ driverId }));
    });

    it('derives the seat layout and seat count from the vehicle type', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);
      const expectedLayout = resolveVehicleTypeTemplate('sedan').layout;

      const result = await service.create(dto, driverId);

      expect(result.seatLayout).toEqual(expectedLayout);
      expect(result.seats).toBe(countSeatsInLayout(expectedLayout));
    });

    it('keeps a seat layout the client supplied', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);
      const seatLayout = resolveVehicleTypeTemplate('sedan').layout;

      const result = await service.create(
        { ...dto, seatLayout } as CreateVehicleDto,
        driverId,
      );

      expect(result.seatLayout).toEqual(seatLayout);
    });

    it('refuses a second vehicle for the same driver', async () => {
      vehicleRepo.findOne.mockResolvedValue(mockVehicle());

      await expect(service.create(dto, driverId)).rejects.toThrow(
        ConflictException,
      );
      expect(vehicleRepo.save).not.toHaveBeenCalled();
    });
  });

  describe('getVehicleTypes', () => {
    it('returns the catalog of templates', () => {
      const { types } = service.getVehicleTypes();

      expect(Array.isArray(types)).toBe(true);
      expect(types.length).toBeGreaterThan(0);
    });
  });

  describe('findByDriver', () => {
    it('returns the driver vehicle', async () => {
      const vehicle = mockVehicle();
      vehicleRepo.findOne.mockResolvedValue(vehicle);

      await expect(service.findByDriver(driverId)).resolves.toBe(vehicle);
      expect(vehicleRepo.findOne).toHaveBeenCalledWith({ where: { driverId } });
    });

    it('returns null when the driver has no vehicle', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);

      await expect(service.findByDriver(driverId)).resolves.toBeNull();
    });
  });

  describe('findById', () => {
    it('returns the vehicle', async () => {
      const vehicle = mockVehicle();
      vehicleRepo.findOne.mockResolvedValue(vehicle);

      await expect(service.findById(vehicleId)).resolves.toBe(vehicle);
      expect(vehicleRepo.findOne).toHaveBeenCalledWith({
        where: { id: vehicleId },
      });
    });

    it('throws when the vehicle is missing', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);

      await expect(service.findById(vehicleId)).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('update', () => {
    const patch = { model: 'Honda Accord' } as UpdateVehicleDto;

    it('applies the patch for the owner', async () => {
      const vehicle = mockVehicle();
      vehicleRepo.findOne.mockResolvedValue(vehicle);

      const result = await service.update(vehicleId, patch, driverId);

      expect(vehicleRepo.merge).toHaveBeenCalledWith(vehicle, patch);
      expect(vehicleRepo.save).toHaveBeenCalledWith(vehicle);
      expect(result.model).toBe('Honda Accord');
    });

    it('throws when the vehicle is missing', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);

      await expect(service.update(vehicleId, patch, driverId)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('refuses a driver who does not own the vehicle', async () => {
      vehicleRepo.findOne.mockResolvedValue(mockVehicle());

      await expect(
        service.update(vehicleId, patch, otherDriverId),
      ).rejects.toThrow(ForbiddenException);
      expect(vehicleRepo.save).not.toHaveBeenCalled();
    });
  });

  describe('delete', () => {
    it('removes the vehicle for the owner and returns it', async () => {
      const vehicle = mockVehicle();
      vehicleRepo.findOne.mockResolvedValue(vehicle);

      const result = await service.delete(vehicleId, driverId);

      expect(vehicleRepo.remove).toHaveBeenCalledWith(vehicle);
      expect(result).toBe(vehicle);
    });

    it('throws when the vehicle is missing', async () => {
      vehicleRepo.findOne.mockResolvedValue(null);

      await expect(service.delete(vehicleId, driverId)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('refuses a driver who does not own the vehicle', async () => {
      vehicleRepo.findOne.mockResolvedValue(mockVehicle());

      await expect(service.delete(vehicleId, otherDriverId)).rejects.toThrow(
        ForbiddenException,
      );
      expect(vehicleRepo.remove).not.toHaveBeenCalled();
    });
  });
});
