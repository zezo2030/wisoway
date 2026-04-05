import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as jwt from 'jsonwebtoken';
import { UsersService } from '../users/users.service';
import { UserEntity } from '../../database/entities/user.entity';
import { PgUserRole } from '../../database/entities/shared.enums';
import { PendingRegistrationGender } from '../../database/entities/pending-registration.entity';
import { SignUpDto } from './dto/sign-up.dto';
import { SignInDto } from './dto/sign-in.dto';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { Twilio } from 'twilio';

export interface AuthResponse {
  user: {
    id: string;
    email: string | null;
    phoneNumber: string | null;
    name: string;
    gender: string | null;
    role: string;
    photoUrl: string | null;
    rating: number;
    totalRatings: number;
    isPhoneVerified: boolean;
    isEmailVerified: boolean;
    isDriverApproved: boolean;
    createdAt: Date;
  };
  accessToken: string;
  refreshToken: string;
}

export interface RegisterResponse {
  message: string;
  phoneNumber: string;
  expiresAt: Date;
}

type OtpProvider = 'twilio' | 'local';

@Injectable()
export class AuthService {
  private twilioClient: Twilio;
  private twilioVerifyServiceSid: string | undefined;
  private otpProvider: OtpProvider;

  constructor(
    private usersService: UsersService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {
    const accountSid = this.configService.get<string>('TWILIO_ACCOUNT_SID');
    const authToken = this.configService.get<string>('TWILIO_AUTH_TOKEN');
    const apiKeySid = this.configService.get<string>('TWILIO_API_KEY_SID');
    const apiKeySecret = this.configService.get<string>(
      'TWILIO_API_KEY_SECRET',
    );
    this.twilioVerifyServiceSid = this.configService.get<string>(
      'TWILIO_VERIFY_SERVICE_SID',
    );
    const provider = this.configService
      .get<string>('OTP_PROVIDER')
      ?.toLowerCase();
    this.otpProvider = provider === 'local' ? 'local' : 'twilio';

    if (
      accountSid &&
      apiKeySid &&
      apiKeySecret &&
      accountSid.startsWith('AC') &&
      apiKeySid.startsWith('SK')
    ) {
      this.twilioClient = new Twilio(apiKeySid, apiKeySecret, { accountSid });
    } else if (accountSid && authToken && accountSid.startsWith('AC')) {
      this.twilioClient = new Twilio(accountSid, authToken);
    }
  }

  async register(signUpDto: SignUpDto): Promise<RegisterResponse> {
    const { email, password, name, gender, phoneNumber, role } = signUpDto;

    // Validate email not in User table
    const existingUser = await this.usersService.findByEmail(email);
    if (existingUser) {
      throw new ConflictException('البريد الإلكتروني مسجّل بالفعل');
    }

    // Validate phoneNumber not in User table
    const existingUserByPhone =
      await this.usersService.findByPhone(phoneNumber);
    if (existingUserByPhone) {
      throw new ConflictException('رقم الهاتف مسجّل بالفعل');
    }

    // Validate email not in PendingRegistration with different phone
    const existingPendingByEmail =
      await this.usersService.findPendingByEmail(email);
    if (
      existingPendingByEmail &&
      existingPendingByEmail.phoneNumber !== phoneNumber
    ) {
      throw new ConflictException('البريد الإلكتروني مسجّل بالفعل');
    }

    // Create pending registration (upsert by phone)
    const pendingReg = await this.usersService.createPendingRegistration({
      phoneNumber,
      email,
      passwordHash: password, // Will be hashed in createPendingRegistration
      name,
      gender: gender as unknown as PendingRegistrationGender,
      role: role as unknown as PgUserRole,
    });

    // Send OTP
    await this.sendOtp({ phoneNumber });

    return {
      message: 'OTP sent successfully. Please verify your phone number.',
      phoneNumber,
      expiresAt: pendingReg.expiresAt,
    };
  }

  async login(signInDto: SignInDto): Promise<AuthResponse> {
    const normalizedEmail = signInDto.email.trim().toLowerCase();
    const password = signInDto.password;

    // Find user
    const user = await this.usersService.findByEmailWithPassword(normalizedEmail);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Check if user has password (social login users might not)
    if (!user.passwordHash) {
      throw new UnauthorizedException(
        'Please login using your social provider',
      );
    }

    // Verify password. Support legacy plaintext passwords and migrate them
    // to bcrypt after first successful login.
    let isPasswordValid = false;
    const isBcryptHash =
      user.passwordHash.startsWith('$2b$') ||
      user.passwordHash.startsWith('$2a$') ||
      user.passwordHash.startsWith('$2y$');

    if (isBcryptHash) {
      isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    } else {
      isPasswordValid = password === user.passwordHash;
      if (isPasswordValid) {
        await this.usersService.updatePasswordHash(user.id, password);
      }
    }
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Check if user is active
    if (!user.isActive) {
      throw new UnauthorizedException('Account is inactive');
    }

    // Require phone verification for email signups before allowing login
    if (user.provider === 'email' && !user.isPhoneVerified) {
      throw new UnauthorizedException(
        'PHONE_VERIFICATION_REQUIRED: Please verify your phone number to activate your account.',
      );
    }

    // Generate tokens
    const tokens = await this.generateTokens(user);

    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  async sendOtp(
    sendOtpDto: SendOtpDto,
  ): Promise<{ message: string; expiresIn: number }> {
    const { phoneNumber } = sendOtpDto;

    if (this.otpProvider === 'local') {
      const code = String(Math.floor(100000 + Math.random() * 900000));
      await this.usersService.createOtpCode(phoneNumber, code);
      console.log(`[OTP Local] Phone: ${phoneNumber} → Code: ${code}`);
      return {
        message: 'OTP sent successfully',
        expiresIn: 300,
      };
    }

    try {
      if (!this.twilioClient || !this.twilioVerifyServiceSid) {
        throw new BadRequestException(
          'Twilio Verify is not configured correctly',
        );
      }

      await this.twilioClient.verify.v2
        .services(this.twilioVerifyServiceSid)
        .verifications.create({
          to: phoneNumber,
          channel: 'sms',
        });
    } catch (error) {
      console.error('Failed to send OTP via Twilio Verify:', error);
      throw new BadRequestException('Failed to send OTP');
    }

    return {
      message: 'OTP sent successfully',
      expiresIn: 300,
    };
  }

  async verifyOtp(verifyOtpDto: VerifyOtpDto): Promise<AuthResponse> {
    const { phoneNumber, code } = verifyOtpDto;

    await this.verifyPhoneOtp(phoneNumber, code);

    // Check if there's a pending registration for this phone
    const pendingReg = await this.usersService.findPendingByPhone(phoneNumber);

    let user: UserEntity;

    if (pendingReg) {
      // Create user from pending registration
      user = await this.usersService.create({
        phoneNumber,
        email: pendingReg.email,
        passwordHash: pendingReg.passwordHash,
        name: pendingReg.name,
        gender: pendingReg.gender as string,
        role: pendingReg.role as unknown as PgUserRole,
        provider: 'email',
        isPhoneVerified: true,
        isActive: true,
      });

      // Delete the pending registration
      await this.usersService.deletePendingByPhone(phoneNumber);
    } else {
      // No pending registration, check for existing user (linkPhone fallback)
      const found = await this.usersService.findByPhone(phoneNumber);
      if (!found) {
        throw new NotFoundException('لا يوجد تسجيل معلّق لهذا الرقم');
      }
      user = found;

      // Update existing user's phone verification status
      if (!user.isPhoneVerified) {
        await this.usersService.linkPhone(user.id, phoneNumber);
      }
    }

    // Generate tokens
    const tokens = await this.generateTokens(user);

    return {
      user: this.sanitizeUser(user),
      ...tokens,
    };
  }

  async refreshTokens(
    refreshTokenDto: RefreshTokenDto,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const { refreshToken } = refreshTokenDto;

    try {
      // Use raw jsonwebtoken to verify (consistent with how we sign in generateTokens)
      const refreshSecret =
        this.configService.get<string>('JWT_REFRESH_SECRET');
      if (!refreshSecret) {
        throw new Error('JWT_REFRESH_SECRET is not configured');
      }

      const payload = jwt.verify(refreshToken, refreshSecret) as any;

      // Find user by subject first, then fall back to email for legacy tokens
      let user: UserEntity | null = null;
      if (payload?.sub) {
        try {
          user = await this.usersService.findById(payload.sub);
        } catch {
          user = null;
        }
      }

      if (!user && payload?.email) {
        user = await this.usersService.findByEmail(payload.email);
      }

      if (!user || !user.isActive) {
        throw new UnauthorizedException('User not found or inactive');
      }

      // Generate new tokens
      return this.generateTokens(user);
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error('Refresh token error:', msg);
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async logout(userId: string): Promise<{ message: string }> {
    // Clear refresh token
    await this.usersService.updateRefreshToken(userId, '');
    return { message: 'Logged out successfully' };
  }

  async forgotPassword(email: string): Promise<{ message: string }> {
    const user = await this.usersService.findByEmail(email);
    if (!user) {
      // Don't reveal if email exists
      return { message: 'Password reset email sent' };
    }

    // Generate reset token (in a real app, send email with reset link)
    // For now, we'll just return a message
    // TODO: Implement email service for password reset
    return { message: 'Password reset email sent' };
  }

  async resetPassword(
    token: string,
    newPassword: string,
  ): Promise<{ message: string }> {
    // Verify reset token and update password
    // TODO: Implement password reset with token verification
    return { message: 'Password reset successfully' };
  }

  async changePassword(
    userId: string,
    dto: ChangePasswordDto,
  ): Promise<{ message: string }> {
    const user = await this.usersService.findByIdWithPassword(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (!user.passwordHash) {
      throw new BadRequestException(
        'This account has no password. Use the sign-in method you registered with.',
      );
    }

    const { currentPassword, newPassword } = dto;
    if (currentPassword === newPassword) {
      throw new BadRequestException(
        'New password must be different from the current password',
      );
    }

    const isBcryptHash =
      user.passwordHash.startsWith('$2b$') ||
      user.passwordHash.startsWith('$2a$') ||
      user.passwordHash.startsWith('$2y$');

    let isCurrentValid = false;
    if (isBcryptHash) {
      isCurrentValid = await bcrypt.compare(
        currentPassword,
        user.passwordHash,
      );
    } else {
      isCurrentValid = currentPassword === user.passwordHash;
    }

    if (!isCurrentValid) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    await this.usersService.updatePasswordHash(userId, newPassword);
    return { message: 'Password changed successfully' };
  }

  async linkPhone(
    userId: string,
    phoneNumber: string,
    code: string,
  ): Promise<{ message: string; isPhoneVerified: boolean }> {
    await this.verifyPhoneOtp(phoneNumber, code);

    // Check if phone is already linked to another user
    const existingUser = await this.usersService.findByPhone(phoneNumber);
    if (existingUser && existingUser.id !== userId) {
      throw new ConflictException('رقم الهاتف مرتبط بحساب آخر');
    }

    // Link phone to user
    await this.usersService.linkPhone(userId, phoneNumber);

    return {
      message: 'Phone linked successfully',
      isPhoneVerified: true,
    };
  }

  async deleteAccount(userId: string): Promise<{ message: string }> {
    await this.usersService.delete(userId);
    return { message: 'Account deleted successfully' };
  }

  private async generateTokens(
    user: UserEntity,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
    };

    const accessSecret = this.configService.get<string>('JWT_ACCESS_SECRET');
    const refreshSecret = this.configService.get<string>('JWT_REFRESH_SECRET');

    if (!accessSecret || !refreshSecret) {
      throw new Error('JWT secrets are not configured');
    }

    const accessToken = jwt.sign(payload, accessSecret, {
      expiresIn: '15m',
    });

    const refreshToken = jwt.sign(payload, refreshSecret, {
      expiresIn: '7d',
    });

    // Store refresh token hash in database
    await this.usersService.updateRefreshToken(user.id, refreshToken);

    return {
      accessToken,
      refreshToken,
    };
  }

  private sanitizeUser(user: UserEntity) {
    return {
      id: user.id,
      email: user.email ?? '',
      phoneNumber: user.phoneNumber ?? '',
      name: user.name,
      gender: user.gender ?? 'male',
      role: user.role,
      photoUrl: user.photoUrl,
      rating: Number(user.rating),
      totalRatings: Number(user.totalRatings),
      isPhoneVerified: user.isPhoneVerified,
      isEmailVerified: user.isEmailVerified,
      isDriverApproved: user.isDriverApproved,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  private async verifyPhoneOtp(
    phoneNumber: string,
    code: string,
  ): Promise<void> {
    if (this.otpProvider === 'local') {
      const otp = await this.usersService.findOtpCode(phoneNumber, code);
      if (!otp) {
        throw new UnauthorizedException('Invalid or expired OTP code');
      }
      await this.usersService.markOtpCodeAsUsed(otp.id);
      return;
    }

    if (!this.twilioClient || !this.twilioVerifyServiceSid) {
      throw new BadRequestException(
        'Twilio Verify is not configured correctly',
      );
    }

    try {
      const verificationCheck = await this.twilioClient.verify.v2
        .services(this.twilioVerifyServiceSid)
        .verificationChecks.create({
          to: phoneNumber,
          code,
        });

      if (verificationCheck.status !== 'approved') {
        throw new UnauthorizedException('Invalid or expired OTP code');
      }
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      console.error('Failed to verify OTP via Twilio Verify:', error);
      throw new UnauthorizedException('Invalid or expired OTP code');
    }
  }
}
