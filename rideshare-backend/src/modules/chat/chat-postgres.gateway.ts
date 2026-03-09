import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards, Logger } from '@nestjs/common';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ChatPostgresService } from './chat-postgres.service';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/chat',
})
@UseGuards(WsAuthGuard, WsRateLimitGuard)
export class ChatPostgresGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatPostgresGateway.name);
  private userRooms = new Map<string, Set<string>>();

  constructor(private readonly chatService: ChatPostgresService) {}

  async handleConnection(client: Socket) {
    const userId = client.data.userId;
    if (userId) {
      this.userRooms.set(userId, new Set());
    }
    this.logger.log(`User ${userId} connected to chat gateway`);
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    if (!userId) {
      return;
    }
    const joinedRooms = this.userRooms.get(userId);

    if (joinedRooms) {
      joinedRooms.forEach((roomId) => {
        client.leave(`room:${roomId}`);
      });
      this.userRooms.delete(userId);
    }

    this.logger.log(`User ${userId} disconnected from chat gateway`);
  }

  @SubscribeMessage('joinRoom')
  async joinRoom(
    @MessageBody() data: { chatRoomId: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { chatRoomId } = data;
    const userRooms = this.userRooms.get(userId);

    if (userRooms) {
      userRooms.add(chatRoomId);
    }

    client.join(`room:${chatRoomId}`);
    this.logger.log(`User ${userId} joined room ${chatRoomId}`);

    return { event: 'joined', chatRoomId };
  }

  @SubscribeMessage('leaveRoom')
  async leaveRoom(
    @MessageBody() data: { chatRoomId: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { chatRoomId } = data;
    const userRooms = this.userRooms.get(userId);

    if (userRooms) {
      userRooms.delete(chatRoomId);
    }

    client.leave(`room:${chatRoomId}`);
    this.logger.log(`User ${userId} left room ${chatRoomId}`);

    return { event: 'left', chatRoomId };
  }

  @SubscribeMessage('sendMessage')
  async sendMessage(
    @MessageBody() data: { chatRoomId: string; text: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { chatRoomId, text } = data;

    try {
      const message = await this.chatService.sendMessage(
        chatRoomId,
        userId,
        text,
      );

      const payload = {
        _id: message.id,
        id: message.id,
        chatRoomId: message.chatRoomId,
        senderId: message.senderId,
        senderName: message.senderName,
        text: message.text,
        createdAt: message.createdAt,
      };

      this.server.to(`room:${chatRoomId}`).emit('newMessage', payload);

      return { event: 'messageSent', messageId: message.id };
    } catch (error) {
      this.logger.error(`Error sending message: ${error.message}`);
      return { event: 'error', message: error.message };
    }
  }

  @SubscribeMessage('typing')
  async handleTyping(
    @MessageBody() data: { chatRoomId: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { chatRoomId } = data;
    const user = (client as any).user;

    this.server.to(`room:${chatRoomId}`).emit('userTyping', {
      chatRoomId,
      userId,
      userName: user?.name || 'Unknown',
    });

    return { event: 'typing' };
  }

  @SubscribeMessage('stopTyping')
  async handleStopTyping(
    @MessageBody() data: { chatRoomId: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { chatRoomId } = data;

    this.server.to(`room:${chatRoomId}`).emit('userStopTyping', {
      chatRoomId,
      userId,
    });

    return { event: 'stoppedTyping' };
  }

  async emitNewMessage(chatRoomId: string, message: {
    id: string;
    chatRoomId: string;
    senderId: string;
    senderName: string | null;
    text: string;
    createdAt: Date;
  }) {
    this.server.to(`room:${chatRoomId}`).emit('newMessage', {
      _id: message.id,
      id: message.id,
      chatRoomId: message.chatRoomId,
      senderId: message.senderId,
      senderName: message.senderName,
      text: message.text,
      createdAt: message.createdAt,
    });
  }
}
