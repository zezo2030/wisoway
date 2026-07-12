import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { DriverAvailabilityService } from './driver-availability.service';
import { InstantRidesService } from './instant-rides.service';
import { HeartbeatDto, SetAvailabilityDto } from './dto/set-availability.dto';
import { CreateInstantRequestDto } from './dto/create-instant-request.dto';

@ApiTags('instant-rides')
@Controller('instant-rides')
@UseGuards(JwtAuthGuard, RolesGuard)
@ApiBearerAuth()
export class InstantRidesController {
  constructor(
    private readonly availability: DriverAvailabilityService,
    private readonly instantRides: InstantRidesService,
  ) {}

  @Post('availability')
  @Roles('driver')
  @ApiOperation({ summary: 'Driver goes online/offline for instant rides' })
  @ApiResponse({ status: 201, description: 'Availability updated' })
  @ApiResponse({ status: 403, description: 'Driver or vehicle not approved' })
  setAvailability(
    @CurrentUser('id') driverId: string,
    @Body() dto: SetAvailabilityDto,
  ) {
    return this.availability.setAvailability(driverId, dto);
  }

  @Post('availability/heartbeat')
  @Roles('driver')
  @ApiOperation({ summary: 'Update idle driver location while online' })
  @ApiResponse({ status: 201, description: 'Location updated' })
  @ApiResponse({ status: 403, description: 'Driver is not online' })
  heartbeat(@CurrentUser('id') driverId: string, @Body() dto: HeartbeatDto) {
    return this.availability.heartbeat(driverId, dto.latitude, dto.longitude);
  }

  @Get('availability/me')
  @Roles('driver')
  @ApiOperation({ summary: 'Get current driver availability status' })
  @ApiResponse({ status: 200, description: 'Availability status returned' })
  myStatus(@CurrentUser('id') driverId: string) {
    return this.availability.getStatus(driverId);
  }

  // ── Passenger: request an instant ride ──────────────────────────────────────

  @Post('requests')
  @ApiOperation({ summary: 'Passenger requests an instant (on-demand) ride' })
  @ApiResponse({ status: 201, description: 'Request created, searching' })
  @ApiResponse({ status: 409, description: 'An active request already exists' })
  createRequest(
    @CurrentUser('id') passengerId: string,
    @Body() dto: CreateInstantRequestDto,
  ) {
    return this.instantRides.createRequest(passengerId, dto);
  }

  @Get('requests/:id')
  @ApiOperation({ summary: 'Poll an instant request status' })
  @ApiResponse({ status: 200, description: 'Request status returned' })
  getRequest(@Param('id') id: string, @CurrentUser('id') passengerId: string) {
    return this.instantRides.getRequest(id, passengerId);
  }

  @Delete('requests/:id')
  @ApiOperation({ summary: 'Cancel an instant request while searching' })
  @ApiResponse({ status: 200, description: 'Request cancelled' })
  cancelRequest(
    @Param('id') id: string,
    @CurrentUser('id') passengerId: string,
  ) {
    return this.instantRides.cancelRequest(id, passengerId);
  }

  // ── Driver: respond to offers ───────────────────────────────────────────────

  @Get('offers/pending')
  @Roles('driver')
  @ApiOperation({ summary: 'Get the driver’s currently outstanding offer' })
  @ApiResponse({ status: 200, description: 'Pending offer (or null) returned' })
  pendingOffer(@CurrentUser('id') driverId: string) {
    return this.instantRides.getPendingOffer(driverId);
  }

  @Post('offers/:id/accept')
  @Roles('driver')
  @ApiOperation({ summary: 'Driver accepts an instant-ride offer' })
  @ApiResponse({ status: 201, description: 'Offer accepted, trip created' })
  @ApiResponse({ status: 409, description: 'Offer no longer available' })
  acceptOffer(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.instantRides.acceptOffer(id, driverId);
  }

  @Post('offers/:id/decline')
  @Roles('driver')
  @ApiOperation({ summary: 'Driver declines an instant-ride offer' })
  @ApiResponse({ status: 201, description: 'Offer declined' })
  declineOffer(@Param('id') id: string, @CurrentUser('id') driverId: string) {
    return this.instantRides.declineOffer(id, driverId);
  }
}
