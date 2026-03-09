import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-facebook';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';
import { AuthProvider } from '../../users/schemas/user.schema';
import { PgUserRole } from '../../../database/entities/shared.enums';

@Injectable()
export class FacebookStrategy extends PassportStrategy(Strategy, 'facebook') {
  constructor(
    private configService: ConfigService,
    private usersService: UsersService,
  ) {
    const clientID =
      configService.get<string>('FACEBOOK_APP_ID') || 'dummy_facebook_app_id';
    const clientSecret =
      configService.get<string>('FACEBOOK_APP_SECRET') ||
      'dummy_facebook_app_secret';
    const callbackURL =
      configService.get<string>('FACEBOOK_CALLBACK_URL') ||
      'http://localhost/dummy-facebook-callback';

    super({
      clientID,
      clientSecret,
      callbackURL,
      profileFields: ['id', 'emails', 'name', 'photos'],
      enableProof: true,
    });
  }

  async validate(
    accessToken: string,
    refreshToken: string,
    profile: any,
    done: (error: any, user?: any) => void,
  ): Promise<any> {
    try {
      const { id, emails, name, photos } = profile;

      if (!emails || emails.length === 0) {
        throw new UnauthorizedException('No email found in Facebook profile');
      }

      const email = emails[0].value;
      const firstName = name?.givenName || '';
      const lastName = name?.familyName || '';
      const fullName = `${firstName} ${lastName}`.trim() || email.split('@')[0];
      const photoUrl = photos?.[0]?.value || null;

      // Check if user exists with this Facebook ID
      let user = await this.usersService.findByProviderId(
        AuthProvider.FACEBOOK,
        id,
      );

      if (!user) {
        // Check if user exists with this email
        user = await this.usersService.findByEmail(email);

        if (user) {
          // Link Facebook account to existing user
          user = await this.usersService.linkProvider(
            user.id,
            AuthProvider.FACEBOOK,
            id,
          );
        } else {
          // Create new user
          user = await this.usersService.create({
            email,
            name: fullName,
            photoUrl,
            provider: AuthProvider.FACEBOOK,
            providerId: id,
            role: PgUserRole.PASSENGER,
            isEmailVerified: true, // Facebook email is verified
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
