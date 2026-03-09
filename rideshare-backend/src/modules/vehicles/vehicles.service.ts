import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';

@Injectable()
export class VehiclesService {
  constructor(
    @InjectRepository(VehicleEntity)
    private vehicleRepo: Repository<VehicleEntity>,
  ) {}

  async create(
    createVehicleDto: CreateVehicleDto,
    driverId: string,
  ): Promise<VehicleEntity> {
    const existingVehicle = await this.vehicleRepo.findOne({
      where: { driverId },
    });
    if (existingVehicle) {
      throw new ConflictException('Driver already has a vehicle');
    }

    const vehicle = this.vehicleRepo.create({
      ...createVehicleDto,
      driverId,
    });
    return this.vehicleRepo.save(vehicle);
  }

  async findByDriver(driverId: string): Promise<VehicleEntity | null> {
    return this.vehicleRepo.findOne({ where: { driverId } });
  }

  async findById(vehicleId: string): Promise<VehicleEntity> {
    const vehicle = await this.vehicleRepo.findOne({
      where: { id: vehicleId },
    });
    if (!vehicle) {
      throw new NotFoundException('Vehicle not found');
    }
    return vehicle;
  }

  async update(
    vehicleId: string,
    updateVehicleDto: UpdateVehicleDto,
    driverId: string,
  ): Promise<VehicleEntity> {
    const vehicle = await this.findById(vehicleId);
    if (vehicle.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this vehicle');
    }
    this.vehicleRepo.merge(vehicle, updateVehicleDto);
    return this.vehicleRepo.save(vehicle);
  }

  async delete(vehicleId: string, driverId: string): Promise<VehicleEntity> {
    const vehicle = await this.findById(vehicleId);
    if (vehicle.driverId !== driverId) {
      throw new ForbiddenException('You are not the owner of this vehicle');
    }
    await this.vehicleRepo.remove(vehicle);
    return vehicle;
  }
}
