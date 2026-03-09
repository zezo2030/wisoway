import {
  Injectable,
  CanActivate,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class WsAuthGuard implements CanActivate {
  constructor(
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const client = context.switchToWs().getClient();
    const token = this.extractTokenFromClient(client);

    if (!token) {
      throw new UnauthorizedException(
        'WebSocket authentication token not found',
      );
    }

    try {
      const payload = await this.jwtService.verifyAsync(token, {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      });

      // Attach user to the client for use in handlers
      const userId = payload.sub || payload.userId || payload.id;
      client.user = {
        ...payload,
        id: userId,
      };
      client.data = {
        ...(client.data || {}),
        userId,
      };
      return true;
    } catch (error) {
      throw new UnauthorizedException('Invalid or expired WebSocket token');
    }
  }

  private extractTokenFromClient(client: any): string | undefined {
    // Token can be passed via auth object in handshake
    if (client.handshake?.auth?.token) {
      return client.handshake.auth.token;
    }

    // Or via query parameter
    if (client.handshake?.query?.token) {
      return client.handshake.query.token;
    }

    // Or via Authorization header
    const authHeader = client.handshake?.headers?.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      return authHeader.substring(7);
    }

    return undefined;
  }
}
