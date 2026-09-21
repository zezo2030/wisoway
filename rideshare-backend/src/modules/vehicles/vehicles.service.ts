import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import {
  countSeatsInLayout,
  listVehicleTypeTemplates,
  resolveVehicleTypeTemplate,
} from './vehicle-types';

@Injectable()
export class VehiclesService {
  private readonly logger = new Logger(VehiclesService.name);

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

    // When the client doesn't send a custom seat layout, derive it
    // automatically from the selected vehicle type so drivers never have to
    // lay out seats by hand. Seat count always follows the resolved layout.
    let { seatLayout, seats } = createVehicleDto;
    if (!seatLayout) {
      seatLayout = resolveVehicleTypeTemplate(
        createVehicleDto.vehicleType,
        this.logger,
      ).layout;
    }
    if (seats == null) {
      seats = countSeatsInLayout(seatLayout);
    }

    const vehicle = this.vehicleRepo.create({
      ...createVehicleDto,
      seatLayout,
      seats,
      driverId,
    });
    return this.vehicleRepo.save(vehicle);
  }

  getVehicleTypes() {
    return { types: listVehicleTypeTemplates() };
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
