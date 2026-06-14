import {
  Controller,
  Get,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RecurrenceService } from './recurrence.service';
import { UpdateRecurrenceRuleDto } from './dto/recurrence.dto';

@ApiTags('trips')
@Controller('trips/recurrence-rules')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('driver')
@ApiBearerAuth()
export class RecurrenceController {
  constructor(private readonly recurrenceService: RecurrenceService) {}

  @Get()
  @ApiOperation({ summary: "List current driver's recurrence rules" })
  @ApiResponse({ status: 200, description: 'Rules found' })
  async list(@CurrentUser('id') driverId: string) {
    return this.recurrenceService.findByDriver(driverId);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a recurrence rule' })
  @ApiResponse({ status: 200, description: 'Rule updated' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Rule not found' })
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateRecurrenceRuleDto,
    @CurrentUser('id') driverId: string,
  ) {
    return this.recurrenceService.update(id, driverId, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Deactivate a recurrence rule' })
  @ApiResponse({ status: 200, description: 'Rule deactivated' })
  @ApiResponse({ status: 403, description: 'Not the owner' })
  @ApiResponse({ status: 404, description: 'Rule not found' })
  async deactivate(
    @Param('id') id: string,
    @CurrentUser('id') driverId: string,
  ) {
    await this.recurrenceService.deactivate(id, driverId);
    return { success: true, message: 'Rule deactivated' };
  }
}
