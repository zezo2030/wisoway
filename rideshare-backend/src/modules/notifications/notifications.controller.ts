import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Query,
  Body,
  Res,
  UseGuards,
  ParseEnumPipe,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import type { Response } from 'express';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { NotificationQueryDto } from './dto/create-notification.dto';
import { RegisterDeviceDto } from './dto/register-device.dto';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @ApiOperation({ summary: 'Get user notifications' })
  async findAll(
    @CurrentUser('id') userId: string,
    @Query() paginationDto: PaginationDto,
    @Query() queryDto: NotificationQueryDto,
  ) {
    return this.notificationsService.findByUser(userId, {
      page: paginationDto.page || 1,
      limit: paginationDto.limit || 10,
      isRead: queryDto.isRead,
    });
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'Get unread notification count' })
  async getUnreadCount(@CurrentUser('id') userId: string) {
    const count = await this.notificationsService.getUnreadCount(userId);
    return { success: true, data: { count } };
  }

  @Patch(':id/read')
  @ApiOperation({ summary: 'Mark notification as read' })
  async markRead(@Param('id') id: string, @CurrentUser('id') userId: string) {
    const notification = await this.notificationsService.markRead(id, userId);
    return { success: true, data: notification };
  }

  @Patch('read-all')
  @ApiOperation({ summary: 'Mark all notifications as read' })
  async markAllRead(@CurrentUser('id') userId: string) {
    const updatedCount = await this.notificationsService.markAllRead(userId);
    return {
      success: true,
      data: { message: 'All notifications marked as read', updatedCount },
    };
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete notification' })
  async delete(@Param('id') id: string, @CurrentUser('id') userId: string) {
    await this.notificationsService.delete(id, userId);
    return { success: true, data: { message: 'Notification deleted' } };
  }

  @Post('devices')
  @Throttle({ default: { ttl: 60000, limit: 30 } })
  @ApiOperation({ summary: 'Register or refresh a device FCM token' })
  async registerDevice(
    @CurrentUser('id') userId: string,
    @Body() dto: RegisterDeviceDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const result = await this.notificationsService.registerDevice(userId, dto);
    res.status(result.isNew ? HttpStatus.CREATED : HttpStatus.OK);
    return {
      registered: true,
      platform: result.platform,
      lastSeenAt: result.lastSeenAt.toISOString(),
    };
  }

  @Delete('devices/:token')
  @Throttle({ default: { ttl: 60000, limit: 30 } })
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Deregister a device token (sign-out)' })
  async deregisterDevice(
    @CurrentUser('id') userId: string,
    @Param('token') token: string,
  ) {
    await this.notificationsService.deregisterDevice(userId, token);
  }
}
