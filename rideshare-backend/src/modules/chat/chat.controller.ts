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
import { ChatService } from './chat.service';
import { SendMessageDto } from './dto/send-message.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/schemas/user.schema';
import { PaginationDto } from '../../common/dto/pagination.dto';

@ApiTags('Chat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get('rooms')
  @ApiOperation({ summary: 'Get all chat rooms for the current user' })
  @ApiQuery({
    name: 'page',
    required: false,
    type: Number,
    description: 'Page number',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    description: 'Items per page',
  })
  @ApiResponse({
    status: 200,
    description: 'Returns paginated list of chat rooms',
  })
  async getRooms(@CurrentUser() user: User, @Query() query: PaginationDto) {
    return this.chatService.getRoomsByUser(user._id.toString(), query);
  }

  @Get('rooms/:tripId')
  @ApiOperation({ summary: 'Get chat room by trip ID' })
  @ApiParam({ name: 'tripId', description: 'Trip ID' })
  @ApiResponse({
    status: 200,
    description: 'Returns the chat room for the trip',
  })
  @ApiResponse({ status: 403, description: 'User is not a trip participant' })
  async getRoomByTripId(
    @Param('tripId') tripId: string,
    @CurrentUser() user: User,
  ) {
    return this.chatService.getOrCreateRoom(tripId, user._id.toString());
  }

  @Get('rooms/:id/messages')
  @ApiOperation({ summary: 'Get messages for a chat room' })
  @ApiParam({ name: 'id', description: 'Chat room ID' })
  @ApiQuery({
    name: 'page',
    required: false,
    type: Number,
    description: 'Page number',
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    description: 'Items per page (default: 50)',
  })
  @ApiResponse({
    status: 200,
    description: 'Returns paginated list of messages',
  })
  @ApiResponse({ status: 403, description: 'User is not a participant' })
  async getMessages(
    @Param('id') roomId: string,
    @CurrentUser() user: User,
    @Query() query: PaginationDto,
  ) {
    return this.chatService.getMessages(roomId, user._id.toString(), {
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
    @CurrentUser() user: User,
  ) {
    return this.chatService.sendMessage(
      roomId,
      user._id.toString(),
      sendMessageDto.text,
    );
  }
}
