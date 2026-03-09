import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback } from 'passport-google-oauth20';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { AuthProvider } from '../../users/schemas/user.schema';
import { PgUserRole } from '../../../database/entities/shared.enums';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(
    private configService: ConfigService,
    private usersService: UsersService,
  ) {
    const clientID =
      configService.get<string>('GOOGLE_CLIENT_ID') || 'dummy_client_id';
    const clientSecret =
      configService.get<string>('GOOGLE_CLIENT_SECRET') ||
      'dummy_client_secret';
    const callbackURL =
      configService.get<string>('GOOGLE_CALLBACK_URL') ||
      'http://localhost/dummy-callback';

    super({
      clientID,
      clientSecret,
      callbackURL,
      scope: ['email', 'profile'],
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: any,
    done: VerifyCallback,
  ): Promise<any> {
    try {
      const { id, emails, name, photos } = profile;

      if (!emails || emails.length === 0) {
        throw new UnauthorizedException('No email found in Google profile');
      }

      const email = emails[0].value;
      const firstName = name?.givenName || '';
      const lastName = name?.familyName || '';
      const fullName = `${firstName} ${lastName}`.trim() || email.split('@')[0];
      const photoUrl = photos?.[0]?.value || null;

      // Check if user exists with this Google ID
      let user = await this.usersService.findByProviderId(
        AuthProvider.GOOGLE,
        id,
      );

      if (!user) {
        // Check if user exists with this email
        user = await this.usersService.findByEmail(email);

        if (user) {
          // Link Google account to existing user
          user = await this.usersService.linkProvider(
            user.id,
            AuthProvider.GOOGLE,
            id,
          );
        } else {
          // Create new user
          user = await this.usersService.create({
            email,
            name: fullName,
            photoUrl,
            provider: AuthProvider.GOOGLE,
            providerId: id,
            role: PgUserRole.PASSENGER,
            isEmailVerified: true, // Google email is verified
            isActive: true,
          });
        }
      }

      done(null, user);
    } catch (error) {
      done(error, false);
    }
  }
}
