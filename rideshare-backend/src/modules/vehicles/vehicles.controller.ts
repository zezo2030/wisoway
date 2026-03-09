import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('vehicles')
@Controller('vehicles')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Post()
  @Roles('driver')
  @ApiOperation({ summary: 'Create a new vehicle' })
  @ApiResponse({ status: 201, description: 'Vehicle created successfully' })
  @ApiResponse({ status: 400, description: 'Bad request' })
  @ApiResponse({ status: 409, description: 'Driver already has a vehicle' })
  async create(
    @Body() createVehicleDto: CreateVehicleDto,
    @CurrentUser('id') driverId: string,
    @CurrentUser('name') driverName: string,
  ) {
    return this.vehiclesService.create(createVehicleDto, driverId);
  }

  @Get('my')
  @Roles('driver')
  @ApiOperation({ summary: 'Get current driver vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle found' })
  async getMyVehicle(@CurrentUser('id') driverId: string) {
    return this.vehiclesService.findByDriver(driverId);
  }

  @Patch(':id')
  @Roles('driver')
  @ApiOperation({ summary: 'Update vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle updated successfully' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async update(
    @Param('id') id: string,
    @Body() updateVehicleDto: UpdateVehicleDto,
    @CurrentUser('id') driverId: string,
  ) {
    return this.vehiclesService.update(id, updateVehicleDto, driverId);
  }

  @Delete(':id')
  @Roles('driver')
  @ApiOperation({ summary: 'Delete vehicle' })
  @ApiResponse({ status: 200, description: 'Vehicle deleted successfully' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Vehicle not found' })
  async delete(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.vehiclesService.delete(id, driverId);
  }
}
