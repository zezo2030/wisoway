import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { AdminBanService } from './admin-ban.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { PgUserRole } from '../../database/entities/shared.enums';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

export class BanUserDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason: string;
}

/**
 * AdminBanController — T165 / T166 (Phase 8 / US6)
 *
 * POST /admin/users/:id/ban   — ban with cascade (T165)
 * POST /admin/users/:id/unban — clear ban flags (T166)
 */
@ApiTags('Admin — Ban')
@ApiBearerAuth()
@Controller('admin/users')
@Roles(PgUserRole.ADMIN)
export class AdminBanController {
  constructor(private readonly banService: AdminBanService) {}

  /** T165 — Ban a user with full cascade. */
  @Post(':id/ban')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Ban a user and cascade-cancel their bookings/trips/devices',
  })
  @ApiParam({ name: 'id', description: 'Target user UUID' })
  @ApiResponse({ status: 200, description: 'User banned successfully' })
  @ApiResponse({ status: 400, description: 'User is already banned' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async banUser(
    @Param('id', ParseUUIDPipe) userId: string,
    @Body() dto: BanUserDto,
    @CurrentUser() admin: { id: string },
  ) {
    const user = await this.banService.banUser(userId, dto.reason, admin.id);
    return {
      id: user.id,
      bannedAt: user.bannedAt,
      banReason: user.banReason,
    };
  }

  /** T166 — Unban a user (clears bannedAt/banReason only). */
  @Post(':id/unban')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unban a user' })
  @ApiParam({ name: 'id', description: 'Target user UUID' })
  @ApiResponse({ status: 200, description: 'User unbanned successfully' })
  @ApiResponse({ status: 400, description: 'User is not banned' })
  @ApiResponse({ status: 404, description: 'User not found' })
  async unbanUser(
    @Param('id', ParseUUIDPipe) userId: string,
    @CurrentUser() admin: { id: string },
  ) {
    const user = await this.banService.unbanUser(userId, admin.id);
    return {
      id: user.id,
      bannedAt: user.bannedAt,
      banReason: user.banReason,
    };
  }
}
