import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Request,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { ComplaintsService } from './complaints.service';

export class CreateComplaintDto {
  @IsUUID()
  @IsOptional()
  againstUserId?: string;

  @IsUUID()
  @IsOptional()
  tripId?: string;

  @IsUUID()
  @IsOptional()
  bookingId?: string;

  @IsString()
  @IsIn([
    'safety',
    'rude_behavior',
    'no_show',
    'payment',
    'vehicle_condition',
    'other',
  ])
  category: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  body: string;

  /**
   * Custom class-level validation is enforced in the service.
   * At least one of againstUserId | tripId | bookingId must be set.
   */
}

/**
 * ComplaintsController — T167 (Phase 8 / US6)
 *
 * POST /complaints      — user files a complaint
 * GET  /me/complaints   — user lists their complaints
 */
@ApiTags('Complaints')
@ApiBearerAuth()
@Controller()
export class ComplaintsController {
  constructor(private readonly complaintsService: ComplaintsService) {}

  @Post('complaints')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'File a complaint' })
  @ApiBody({ type: CreateComplaintDto })
  @ApiResponse({ status: 201, description: 'Complaint created' })
  @ApiResponse({ status: 400, description: 'No target specified' })
  async create(@Request() req, @Body() dto: CreateComplaintDto) {
    return this.complaintsService.create(req.user.id, dto);
  }

  @Get('me/complaints')
  @ApiOperation({ summary: 'List my filed complaints' })
  @ApiResponse({ status: 200, description: 'Complaints retrieved' })
  async listMine(@Request() req) {
    return this.complaintsService.listMine(req.user.id);
  }
}
