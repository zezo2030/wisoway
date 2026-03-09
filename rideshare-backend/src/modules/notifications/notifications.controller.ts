import {
  Controller,
  Get,
  Patch,
  Delete,
  Param,
  Query,
  UseGuards,
  ParseEnumPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiBearerAuth,
  ApiQuery,
} from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { NotificationQueryDto } from './dto/create-notification.dto';

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
}
