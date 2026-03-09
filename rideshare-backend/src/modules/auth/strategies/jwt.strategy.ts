import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { UserEntity } from '../../../database/entities/user.entity';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    private configService: ConfigService,
    private usersService: UsersService,
  ) {
    const secret = configService.get<string>('JWT_ACCESS_SECRET');
    if (!secret) {
      throw new Error(
        'JWT_ACCESS_SECRET is not defined in environment variables',
      );
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  async validate(payload: any): Promise<UserEntity> {
    const { sub, email } = payload;

    if (!sub && !email) {
      throw new UnauthorizedException('Invalid token payload');
    }

    let user: UserEntity | null = null;

    if (sub) {
      try {
        user = await this.usersService.findById(sub);
      } catch {
        user = null;
      }
    }

    // Some legacy tokens/users can produce an unusable `sub`.
    // Fall back to email when present so valid sessions continue to work.
    if (!user && email) {
      user = await this.usersService.findByEmail(email);
    }

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!user.isActive) {
      throw new UnauthorizedException('User account is inactive');
    }

    return user;
  }
}
