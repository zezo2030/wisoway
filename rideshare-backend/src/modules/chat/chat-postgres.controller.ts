import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';
import { ChatPostgresService } from './chat-postgres.service';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('Chat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatPostgresController {
  constructor(private readonly chatService: ChatPostgresService) {}

  @Get('rooms')
  @ApiOperation({ summary: 'Get all chat rooms for the current user' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Returns paginated list of chat rooms',
  })
  async getRooms(
    @CurrentUser('id') userId: string,
    @Query() query: PaginationDto,
  ) {
    return this.chatService.getRoomsByUser(userId, query);
  }

  @Get('rooms/trip/:tripId/passenger/:passengerId')
  @ApiOperation({
    summary:
      'Get or create 1:1 chat room between driver and passenger (Driver only)',
  })
  @ApiParam({ name: 'tripId', description: 'Trip ID' })
  @ApiParam({ name: 'passengerId', description: 'Passenger user ID' })
  @ApiResponse({
    status: 200,
    description: 'Returns the 1:1 chat room',
  })
  @ApiResponse({ status: 403, description: 'Not driver or fee not paid' })
  async getRoomForDriverPassenger(
    @Param('tripId') tripId: string,
    @Param('passengerId') passengerId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.chatService.getOrCreateRoomForDriverPassenger(
      tripId,
      userId,
      passengerId,
    );
  }

  @Get('rooms/:idOrTripId')
  @ApiOperation({
    summary:
      'Get chat room by room ID or trip ID (for passenger: 1:1 with driver)',
  })
  @ApiParam({
    name: 'idOrTripId',
    description: 'Chat room ID or Trip ID',
  })
  @ApiResponse({
    status: 200,
    description: 'Returns the chat room',
  })
  @ApiResponse({ status: 403, description: 'User is not a participant' })
  async getRoom(
    @Param('idOrTripId') idOrTripId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.chatService.getRoomByIdOrTripId(idOrTripId, userId);
  }

  @Get('rooms/:id/messages')
  @ApiOperation({ summary: 'Get messages for a chat room' })
  @ApiParam({ name: 'id', description: 'Chat room ID' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({
    status: 200,
    description: 'Returns paginated list of messages',
  })
  @ApiResponse({ status: 403, description: 'User is not a participant' })
  async getMessages(
    @Param('id') roomId: string,
    @CurrentUser('id') userId: string,
    @Query() query: PaginationDto,
  ) {
    return this.chatService.getMessages(roomId, userId, {
      page: query.page,
      limit: query.limit || 50,
    });
  }

  @Post('rooms/:id/messages')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Send a message to a chat room' })
  @ApiParam({ name: 'id', description: 'Chat room ID' })
  @ApiResponse({ status: 201, description: 'Message created successfully' })
  @ApiResponse({ status: 403, description: 'User is not a participant' })
  async sendMessage(
    @Param('id') roomId: string,
    @Body() sendMessageDto: SendMessageDto,
    @CurrentUser('id') userId: string,
  ) {
    return this.chatService.sendMessage(roomId, userId, sendMessageDto.text);
  }
}
