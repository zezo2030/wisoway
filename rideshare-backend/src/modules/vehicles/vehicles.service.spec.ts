import { Test, TestingModule } from '@nestjs/testing';
import { getModelToken } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { VehiclesService } from './vehicles.service';
import { Vehicle, VehicleDocument } from './schemas/vehicle.schema';
import {
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';

describe('VehiclesService', () => {
  let service: VehiclesService;
  let vehicleModel: Model<VehicleDocument>;

  const mockVehicleId = '507f1f77bcf86cd799439011';
  const mockDriverId = '507f1f77bcf86cd799439012';
  const mockOtherDriverId = '507f1f77bcf86cd799439013';

  const mockVehicle = {
    _id: mockVehicleId,
    driverId: mockDriverId,
    vehicleType: 'sedan',
    plateNumber: 'ABC123',
    model: 'Toyota Camry',
    seats: 4,
    licenseImageUrl: 'https://s3.amazonaws.com/license.jpg',
    vehicleLicenseImageUrl: 'https://s3.amazonaws.com/vehicle-license.jpg',
    isVerified: false,
    save: jest.fn().mockResolvedValue(true),
  };

  const mockVehicleModel = {
    create: jest.fn(),
    findOne: jest.fn(),
    findById: jest.fn(),
    findOneAndUpdate: jest.fn(),
    findOneAndDelete: jest.fn(),
    deleteOne: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehiclesService,
        {
          provide: getModelToken(Vehicle.name),
          useValue: mockVehicleModel,
        },
      ],
    }).compile();

    service = module.get<VehiclesService>(VehiclesService);
    vehicleModel = module.get<Model<VehicleDocument>>(
      getModelToken(Vehicle.name),
    );
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('should create a vehicle successfully', async () => {
      const createVehicleDto: CreateVehicleDto = {
        vehicleType: 'sedan',
        plateNumber: 'ABC123',
        model: 'Toyota Camry',
        seats: 4,
        licenseImageUrl: 'https://s3.amazonaws.com/license.jpg',
        vehicleLicenseImageUrl: 'https://s3.amazonaws.com/vehicle-license.jpg',
      };

      mockVehicleModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      mockVehicleModel.create.mockResolvedValue(mockVehicle);

      const result = await service.create(createVehicleDto, mockDriverId);

      expect(result).toBeDefined();
      expect(result.driverId).toBe(mockDriverId);
      expect(result.vehicleType).toBe('sedan');
      expect(mockVehicleModel.create).toHaveBeenCalled();
    });

    it('should fail if driver already has a vehicle', async () => {
      const createVehicleDto: CreateVehicleDto = {
        vehicleType: 'sedan',
        plateNumber: 'ABC123',
        model: 'Toyota Camry',
        seats: 4,
      };

      mockVehicleModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      await expect(
        service.create(createVehicleDto, mockDriverId),
      ).rejects.toThrow(ConflictException);
    });
  });

  describe('findByDriver', () => {
    it('should find vehicle by driver ID', async () => {
      mockVehicleModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      const result = await service.findByDriver(mockDriverId);

      expect(result).toBeDefined();
      expect(result.driverId).toBe(mockDriverId);
      expect(mockVehicleModel.findOne).toHaveBeenCalledWith({
        driverId: mockDriverId,
      });
    });

    it('should return null if no vehicle found', async () => {
      mockVehicleModel.findOne.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      const result = await service.findByDriver(mockDriverId);

      expect(result).toBeNull();
    });
  });

  describe('update', () => {
    it('should update vehicle successfully', async () => {
      const updateVehicleDto: UpdateVehicleDto = {
        model: 'Toyota Corolla',
      };

      mockVehicleModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      mockVehicleModel.findOneAndUpdate.mockReturnValue({
        exec: jest
          .fn()
          .mockResolvedValue({ ...mockVehicle, model: 'Toyota Corolla' }),
      });

      const result = await service.update(
        mockVehicleId,
        updateVehicleDto,
        mockDriverId,
      );

      expect(result.model).toBe('Toyota Corolla');
    });

    it('should fail if vehicle not found', async () => {
      const updateVehicleDto: UpdateVehicleDto = { model: 'Toyota Corolla' };

      mockVehicleModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(
        service.update(mockVehicleId, updateVehicleDto, mockDriverId),
      ).rejects.toThrow(NotFoundException);
    });

    it('should fail if user is not the owner', async () => {
      const updateVehicleDto: UpdateVehicleDto = { model: 'Toyota Corolla' };

      mockVehicleModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      await expect(
        service.update(mockVehicleId, updateVehicleDto, mockOtherDriverId),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('delete', () => {
    it('should delete vehicle successfully', async () => {
      mockVehicleModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      mockVehicleModel.findOneAndDelete.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      const result = await service.delete(mockVehicleId, mockDriverId);

      expect(result).toBeDefined();
      expect(result._id).toBe(mockVehicleId);
    });

    it('should fail if vehicle not found', async () => {
      mockVehicleModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      });

      await expect(service.delete(mockVehicleId, mockDriverId)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should fail if user is not the owner', async () => {
      mockVehicleModel.findById.mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockVehicle),
      });

      await expect(
        service.delete(mockVehicleId, mockOtherDriverId),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
