import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { UseGuards, UseInterceptors } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import { WsAuthGuard } from '../../common/guards/ws-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { TrackingService } from './tracking.service';
import { SubscribeTripTrackingDto } from './dto/subscribe-trip-tracking.dto';
import { UpdateDriverLocationDto } from './dto/update-driver-location.dto';
import { WsRateLimitGuard } from '../../common/guards/ws-rate-limit.guard';
import { LocationGuardInterceptor } from '../../common/interceptors/location-guard.interceptor';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/tracking',
})
@UseGuards(WsAuthGuard, WsRateLimitGuard)
export class TrackingGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  async handleConnection(client: Socket) {
    const userId = client.data.userId;
    if (userId) {
      client.join(`user:${userId}`);
    }
  }

  async handleDisconnect(client: Socket) {
    client.removeAllListeners();
  }

  constructor(private readonly trackingService: TrackingService) {}

  @SubscribeMessage('trip:tracking:subscribe')
  async subscribeTrip(
    @MessageBody() dto: SubscribeTripTrackingDto,
    @ConnectedSocket() client: Socket,
    @CurrentUser('id') userId: string,
  ) {
    client.join(`trip:${dto.tripId}`);
    const snapshot = await this.trackingService.getLatestTripLocation(
      dto.tripId,
    );
    return {
      success: true,
      userId,
      tripId: dto.tripId,
      snapshot,
    };
  }

  @SubscribeMessage('trip:tracking:unsubscribe')
  async unsubscribeTrip(
    @MessageBody() dto: SubscribeTripTrackingDto,
    @ConnectedSocket() client: Socket,
  ) {
    client.leave(`trip:${dto.tripId}`);
    return {
      success: true,
      tripId: dto.tripId,
    };
  }

  /**
   * T032 — LocationGuardInterceptor is applied here.
   * Payloads with isMockLocation=true are rejected before this handler runs.
   */
  @SubscribeMessage('driver:location:update')
  @UseInterceptors(LocationGuardInterceptor)
  async updateLocation(
    @MessageBody() dto: UpdateDriverLocationDto,
    @CurrentUser('id') driverId: string,
  ) {
    const saved = await this.trackingService.updateDriverLocation(
      driverId,
      dto,
    );
    this.server.to(`trip:${dto.tripId}`).emit('trip:tracking:update', saved);
    return { success: true, data: saved };
  }

  async emitTripTrackingSnapshot(tripId: string) {
    const snapshot = await this.trackingService.getLatestTripLocation(tripId);
    if (snapshot) {
      this.server.to(`trip:${tripId}`).emit('trip:tracking:snapshot', snapshot);
    }
  }
}
