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
import { UseGuards } from '@nestjs/common';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/trips',
})
@UseGuards(WsAuthGuard, WsRateLimitGuard)
export class TripsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private userTrips = new Map<string, Set<string>>();

  async handleConnection(client: Socket) {
    const userId = client.data.userId;
    if (userId) {
      this.userTrips.set(userId, new Set());
    }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data.userId;
    if (!userId) {
      return;
    }
    const subscribedTrips = this.userTrips.get(userId);

    if (subscribedTrips) {
      subscribedTrips.forEach((tripId) => {
        client.leave(`trip:${tripId}`);
      });
      this.userTrips.delete(userId);
    }
  }

  @SubscribeMessage('subscribeTripUpdates')
  async subscribeTripUpdates(
    @MessageBody() data: { tripId: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { tripId } = data;
    const userTrips = this.userTrips.get(userId);

    if (userTrips) {
      userTrips.add(tripId);
    }

    client.join(`trip:${tripId}`);
    return { event: 'subscribed', tripId };
  }

  @SubscribeMessage('unsubscribeTripUpdates')
  async unsubscribeTripUpdates(
    @MessageBody() data: { tripId: string },
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    const { tripId } = data;
    const userTrips = this.userTrips.get(userId);

    if (userTrips) {
      userTrips.delete(tripId);
    }

    client.leave(`trip:${tripId}`);
    return { event: 'unsubscribed', tripId };
  }

  // Methods to be called from services to emit events
  async emitTripUpdated(tripId: string, data: any) {
    this.server.to(`trip:${tripId}`).emit('tripUpdated', {
      tripId,
      ...data,
    });
  }

  async emitSeatBooked(tripId: string, seatNumber: string, status: string) {
    this.server.to(`trip:${tripId}`).emit('seatBooked', {
      tripId,
      seatNumber,
      status,
    });
  }

  async emitSeatReleased(tripId: string, seatNumber: string) {
    this.server.to(`trip:${tripId}`).emit('seatReleased', {
      tripId,
      seatNumber,
    });
  }
}
