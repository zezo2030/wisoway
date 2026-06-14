import {
  Controller,
  Get,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { AdminFlagsService } from './admin-flags.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { UserRole } from '../users/schemas/user.schema';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AccountFlagDisposition } from '../../database/entities/account-flag.entity';

/**
 * T034–T037 — Admin endpoints for account-flags management and device revoke.
 *
 * All routes require role=admin and a valid JWT.
 *
 * Routes:
 *  GET    /admin/account-flags              — list flags (filterable)
 *  PATCH  /admin/account-flags/:id/resolve  — resolve a flag
 *  PATCH  /admin/account-flags/:id/dismiss  — dismiss a flag
 *  DELETE /admin/devices/:deviceId/revoke   — admin-revoke a device session
 */
@ApiTags('Admin — Account Safety')
@ApiBearerAuth()
@Controller('admin')
@Roles(UserRole.ADMIN)
export class AdminFlagsController {
  constructor(private readonly adminFlagsService: AdminFlagsService) {}

  /** T034 — List account flags */
  @Get('account-flags')
  @ApiOperation({ summary: 'List account flags (admin)' })
  @ApiQuery({ name: 'userId', required: false, type: String })
  @ApiQuery({
    name: 'disposition',
    required: false,
    enum: AccountFlagDisposition,
  })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiQuery({ name: 'offset', required: false, type: Number })
  async listFlags(
    @Query('userId') userId?: string,
    @Query('disposition') disposition?: AccountFlagDisposition,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.adminFlagsService.listFlags({
      userId,
      disposition,
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  /** T035 — Resolve a flag */
  @Patch('account-flags/:flagId/resolve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Resolve an account flag (admin)' })
  @ApiResponse({ status: 200, description: 'Flag resolved' })
  async resolveFlag(
    @Param('flagId', ParseUUIDPipe) flagId: string,
    @CurrentUser('id') adminId: string,
    @Body('notes') notes?: string,
  ) {
    return this.adminFlagsService.resolveFlag(flagId, adminId, notes);
  }

  /** T036 — Dismiss a flag */
  @Patch('account-flags/:flagId/dismiss')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Dismiss an account flag (admin)' })
  @ApiResponse({ status: 200, description: 'Flag dismissed' })
  async dismissFlag(
    @Param('flagId', ParseUUIDPipe) flagId: string,
    @CurrentUser('id') adminId: string,
    @Body('notes') notes?: string,
  ) {
    return this.adminFlagsService.dismissFlag(flagId, adminId, notes);
  }

  /** T037 — Admin-revoke a device session */
  @Delete('devices/:deviceId/revoke')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke a device session (admin)' })
  @ApiResponse({ status: 200, description: 'Device revoked' })
  async revokeDevice(
    @Param('deviceId', ParseUUIDPipe) deviceId: string,
    @CurrentUser('id') adminId: string,
    @Body('reason') reason?: string,
  ) {
    return this.adminFlagsService.revokeDevice(deviceId, adminId, reason);
  }
}
