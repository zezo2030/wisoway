import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { MoreThan, Repository } from 'typeorm';
import { UsersService } from '../users/users.service';
import { UserEntity } from '../../database/entities/user.entity';
import { VehicleEntity } from '../../database/entities/vehicle.entity';
import { UserDeviceStatus } from '../../database/entities/user-device.entity';
import { PasswordResetSessionEntity } from '../../database/entities/password-reset-session.entity';
import { PgUserRole } from '../../database/entities/shared.enums';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto, VerifyOtpDeviceDto } from './dto/verify-otp.dto';
import {
  DriverVerifyPhoneDto,
  RegisterDriverDto,
  DRIVER_REGISTRATION_TOKEN_PURPOSE,
  DRIVER_REGISTRATION_TOKEN_TTL_SECONDS,
} from './dto/register-driver.dto';
import { SignInDto } from './dto/sign-in.dto';
import {
  countSeatsInLayout,
  resolveVehicleTypeTemplate,
} from '../vehicles/vehicle-types';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { VerifyResetOtpDto } from './dto/verify-reset-otp.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { Twilio } from 'twilio';
import { DeviceFingerprintService } from './device-fingerprint.service';
import { AccountRiskService } from './account-risk.service';
import { NotificationsService } from '../notifications/notifications.service';
import { AdminAlertsService } from '../admin/admin-alerts.service';

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
  /** 'active' | 'restricted' | 'banned' — overall account health. */
  accountState: 'active' | 'restricted' | 'banned';
  /** 'active' | 'revoked' | null — state of the device session just registered. */
  deviceState: 'active' | 'revoked' | null;
  /** True for legacy social-login accounts that still need phone linking. */
  pendingPhoneLinkRequired: boolean;
}

type OtpProvider = 'twilio' | 'local';

@Injectable()
export class AuthService {
  private twilioClient: Twilio;
  private twilioVerifyServiceSid: string | undefined;
  private otpProvider: OtpProvider;

  private readonly logger = new Logger(AuthService.name);

  constructor(
    private usersService: UsersService,
    private configService: ConfigService,
    private deviceFingerprintService: DeviceFingerprintService,
    private accountRiskService: AccountRiskService,
    private notificationsService: NotificationsService,
    private adminAlertsService: AdminAlertsService,
    @InjectRepository(UserEntity)
    private userRepo: Repository<UserEntity>,
    @InjectRepository(PasswordResetSessionEntity)
    private passwordResetSessionRepo: Repository<PasswordResetSessionEntity>,
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
    const { phoneNumber, code, device, name, gender, role, password } =
      verifyOtpDto;

    await this.verifyPhoneOtp(phoneNumber, code);

    let user: UserEntity;

    const found = await this.usersService.findByPhone(phoneNumber);
    if (found) {
      user = found;
      if (!user.passwordHash && password) {
        await this.userRepo.update(user.id, {
          passwordHash: await bcrypt.hash(password, 12),
          passwordChangedAt: new Date(),
          isPhoneVerified: true,
        });
        user = await this.usersService.findById(user.id);
      } else if (user.passwordHash) {
        throw new ConflictException(
          'Phone number is already registered. Please sign in with your password.',
        );
      } else if (!password) {
        throw new BadRequestException(
          'Password is required to finish account setup for this phone number.',
        );
      }

      if (!user.isPhoneVerified) {
        await this.usersService.linkPhone(user.id, phoneNumber);
        user = await this.usersService.findById(user.id);
      }
    } else {
      if (!password) {
        throw new BadRequestException(
          'Password is required when creating a new account.',
        );
      }

      const resolvedRole =
        role === 'driver' ? PgUserRole.DRIVER : PgUserRole.PASSENGER;
      user = await this.usersService.create({
        phoneNumber,
        name: name && name.trim().length > 0 ? name.trim() : phoneNumber,
        gender: gender ?? null,
        passwordHash: password,
        role: resolvedRole,
        provider: 'phone',
        isPhoneVerified: true,
        isActive: true,
      });

      this.notifyAdminsOfNewUser(user).catch((err) => {
        this.logger.error(
          `Failed to notify admins of new user ${user.id}: ${(err as Error).message}`,
        );
      });
      this.adminAlertsService.notifyDriverRegistration(user).catch((err) => {
        this.logger.error(
          `Failed to dispatch driver-registration alert ${user.id}: ${(err as Error).message}`,
        );
      });
    }

    // ── Device binding (optional) ──────────────────────────────────────────
    const binding = await this.bindDeviceForUser(user, device);
    user = binding.user;
    const deviceState = binding.deviceState;
    const activeDeviceId = binding.activeDeviceId;

    // ── Build accountState ─────────────────────────────────────────────────
    let accountState: 'active' | 'restricted' | 'banned';
    if (user.bannedAt) {
      accountState = 'banned';
    } else if (user.restricted) {
      accountState = 'restricted';
    } else {
      accountState = 'active';
    }

    // Generate tokens
    const tokens = await this.generateTokens(user, activeDeviceId);

    return {
      user: this.sanitizeUser(user),
      ...tokens,
      accountState,
      deviceState,
      pendingPhoneLinkRequired: user.pendingPhoneLink ?? false,
    };
  }

  /**
   * Step 1 of deferred driver registration. Verifies the OTP to prove phone
   * ownership but does NOT create an account. Returns a short-lived token that
   * authorizes the final register call and the registration image uploads.
   */
  async driverVerifyPhone(
    dto: DriverVerifyPhoneDto,
  ): Promise<{ registrationToken: string; expiresIn: number }> {
    const { phoneNumber, code } = dto;

    await this.verifyPhoneOtp(phoneNumber, code);

    const existing = await this.usersService.findByPhone(phoneNumber);
    if (existing) {
      throw new ConflictException(
        'Phone number is already registered. Please sign in instead.',
      );
    }

    return {
      registrationToken: this.signRegistrationToken(phoneNumber),
      expiresIn: DRIVER_REGISTRATION_TOKEN_TTL_SECONDS,
    };
  }

  /**
   * Final step of deferred driver registration. Creates the driver account and
   * the vehicle in a single transaction so the account only ever exists once
   * the whole onboarding completes — an interrupted flow leaves nothing behind.
   */
  async registerDriver(dto: RegisterDriverDto): Promise<AuthResponse> {
    const phoneNumber = this.verifyRegistrationToken(dto.registrationToken);

    if (await this.usersService.findByPhone(phoneNumber)) {
      throw new ConflictException(
        'Phone number is already registered. Please sign in instead.',
      );
    }

    // Resolve the seat layout from the chosen vehicle type so the seat count is
    // always consistent with the catalog (mirrors VehiclesService.create).
    const seatLayout = resolveVehicleTypeTemplate(
      dto.vehicleType,
      this.logger,
    ).layout;
    const seats = dto.seats ?? countSeatsInLayout(seatLayout);
    const passwordHash = await bcrypt.hash(dto.password, 12);

    let user: UserEntity;
    try {
      user = await this.userRepo.manager.transaction(async (em) => {
        const userRepo = em.getRepository(UserEntity);
        const vehicleRepo = em.getRepository(VehicleEntity);

        const createdUser = userRepo.create({
          phoneNumber,
          name:
            dto.name && dto.name.trim().length > 0
              ? dto.name.trim()
              : phoneNumber,
          gender: dto.gender ?? null,
          photoUrl: dto.photoUrl ?? null,
          passwordHash,
          passwordChangedAt: new Date(),
          role: PgUserRole.DRIVER,
          provider: 'phone',
          isPhoneVerified: true,
          isActive: true,
        });
        const savedUser = await userRepo.save(createdUser);

        const vehicle = vehicleRepo.create({
          driverId: savedUser.id,
          vehicleType: dto.vehicleType,
          plateNumber: dto.plateNumber,
          model: dto.model,
          seats,
          seatLayout,
          licenseImageUrl: dto.licenseImageUrl ?? null,
          vehicleLicenseImageUrl: dto.vehicleLicenseImageUrl ?? null,
          carImageUrl: dto.carImageUrl,
        });
        await vehicleRepo.save(vehicle);

        return savedUser;
      });
    } catch (err) {
      if (err instanceof ConflictException) throw err;
      // Unique-violation safety net for a race between the check and the insert.
      if ((err as { code?: string })?.code === '23505') {
        throw new ConflictException(
          'Phone number is already registered. Please sign in instead.',
        );
      }
      throw err;
    }

    this.notifyAdminsOfNewUser(user).catch((err) => {
      this.logger.error(
        `Failed to notify admins of new user ${user.id}: ${(err as Error).message}`,
      );
    });
    this.adminAlertsService.notifyDriverRegistration(user).catch((err) => {
      this.logger.error(
        `Failed to dispatch driver-registration alert ${user.id}: ${(err as Error).message}`,
      );
    });

    const binding = await this.bindDeviceForUser(user, dto.device);
    user = binding.user;

    const accountState = this.resolveAccountState(user);
    const tokens = await this.generateTokens(user, binding.activeDeviceId);

    return {
      user: this.sanitizeUser(user),
      ...tokens,
      accountState,
      deviceState: binding.deviceState,
      pendingPhoneLinkRequired: user.pendingPhoneLink ?? false,
    };
  }

  async login(signInDto: SignInDto): Promise<AuthResponse> {
    const { email, phoneNumber, password } = signInDto;
    const user = email
      ? await this.findAdminByEmailWithPassword(email)
      : await this.findUserByPhoneWithPassword(phoneNumber!);

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException(
        email
          ? 'Invalid admin email or password'
          : 'Invalid phone number or password',
      );
    }

    const passwordMatches = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatches) {
      throw new UnauthorizedException(
        email
          ? 'Invalid admin email or password'
          : 'Invalid phone number or password',
      );
    }

    if (!email && !user.isPhoneVerified) {
      throw new UnauthorizedException(
        'Phone number must be verified before signing in.',
      );
    }

    const accountState = this.resolveAccountState(user);
    const tokens = await this.generateTokens(user, null);

    return {
      user: this.sanitizeUser(user),
      ...tokens,
      accountState,
      deviceState: null,
      pendingPhoneLinkRequired: user.pendingPhoneLink ?? false,
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
      if (payload?.did) {
        const activeDevice =
          await this.deviceFingerprintService.findActiveDeviceById(
            user.id,
            payload.did,
          );
        if (!activeDevice) {
          throw new UnauthorizedException('Device session is no longer active');
        }
      }

      return this.generateTokens(user, payload?.did ?? null);
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

  async forgotPassword(
    forgotPasswordDto: ForgotPasswordDto,
  ): Promise<{ message: string; expiresIn: number }> {
    const { phoneNumber } = forgotPasswordDto;
    const user = await this.usersService.findByPhone(phoneNumber);

    if (!user) {
      throw new NotFoundException('No account found for this phone number');
    }

    const otpResponse = await this.sendOtp({ phoneNumber });

    await this.passwordResetSessionRepo.delete({ phoneNumber });
    await this.passwordResetSessionRepo.save(
      this.passwordResetSessionRepo.create({
        phoneNumber,
        otpCode: randomUUID(),
        isVerified: false,
        attemptCount: 0,
        isLocked: false,
        expiresAt: new Date(Date.now() + otpResponse.expiresIn * 1000),
      }),
    );

    return otpResponse;
  }

  async verifyResetOtp(
    verifyResetOtpDto: VerifyResetOtpDto,
  ): Promise<{ resetToken: string }> {
    const { phoneNumber, code } = verifyResetOtpDto;
    const session = await this.passwordResetSessionRepo.findOne({
      where: {
        phoneNumber,
        expiresAt: MoreThan(new Date()),
      },
      order: { createdAt: 'DESC' },
    });

    if (!session || session.isLocked) {
      throw new UnauthorizedException(
        'Password reset session is invalid or has expired',
      );
    }

    try {
      await this.verifyPhoneOtp(phoneNumber, code);
    } catch (error) {
      const attemptCount = session.attemptCount + 1;
      const isLocked = attemptCount >= 5;
      await this.passwordResetSessionRepo.update(session.id, {
        attemptCount,
        isLocked,
      });

      if (isLocked) {
        throw new UnauthorizedException(
          'Too many attempts. Please request a new reset code.',
        );
      }

      throw error;
    }

    await this.passwordResetSessionRepo.update(session.id, {
      isVerified: true,
      attemptCount: session.attemptCount + 1,
    });

    return { resetToken: session.id };
  }

  async resetPassword(
    resetPasswordDto: ResetPasswordDto,
  ): Promise<{ message: string }> {
    const { resetToken, newPassword } = resetPasswordDto;
    const session = await this.passwordResetSessionRepo.findOne({
      where: {
        id: resetToken,
        isVerified: true,
        isLocked: false,
        expiresAt: MoreThan(new Date()),
      },
    });

    if (!session) {
      throw new UnauthorizedException('Reset token is invalid or has expired');
    }

    const user = await this.usersService.findByPhone(session.phoneNumber);
    if (!user) {
      throw new NotFoundException('User not found');
    }

    await this.userRepo.update(user.id, {
      passwordHash: await bcrypt.hash(newPassword, 12),
      passwordChangedAt: new Date(),
      refreshToken: null,
    });
    await this.passwordResetSessionRepo.delete({
      phoneNumber: session.phoneNumber,
    });

    return { message: 'Password reset successfully' };
  }

  async changePassword(
    userId: string,
    changePasswordDto: ChangePasswordDto,
  ): Promise<{ message: string }> {
    const { currentPassword, newPassword } = changePasswordDto;
    const user = await this.findUserByIdWithPassword(userId);

    if (!user.passwordHash) {
      throw new BadRequestException('No password is set for this account');
    }

    const passwordMatches = await bcrypt.compare(
      currentPassword,
      user.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    await this.userRepo.update(user.id, {
      passwordHash: await bcrypt.hash(newPassword, 12),
      passwordChangedAt: new Date(),
      refreshToken: null,
    });

    return { message: 'Password changed successfully' };
  }

  private signRegistrationToken(phoneNumber: string): string {
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET');
    if (!secret) {
      throw new Error('JWT secrets are not configured');
    }
    return jwt.sign(
      { phone: phoneNumber, purpose: DRIVER_REGISTRATION_TOKEN_PURPOSE },
      secret,
      { expiresIn: DRIVER_REGISTRATION_TOKEN_TTL_SECONDS },
    );
  }

  /** Verifies a driver-registration token and returns its phone number. */
  verifyRegistrationToken(token: string): string {
    const secret = this.configService.get<string>('JWT_ACCESS_SECRET');
    if (!secret) {
      throw new Error('JWT secrets are not configured');
    }

    let decoded: jwt.JwtPayload | string;
    try {
      decoded = jwt.verify(token, secret);
    } catch {
      throw new UnauthorizedException(
        'Registration session expired. Please verify your phone again.',
      );
    }

    if (
      typeof decoded !== 'object' ||
      decoded.purpose !== DRIVER_REGISTRATION_TOKEN_PURPOSE ||
      typeof decoded.phone !== 'string'
    ) {
      throw new UnauthorizedException('Invalid registration token.');
    }

    return decoded.phone;
  }

  /**
   * Registers/refreshes the device session for a user and runs the multi-account
   * risk check. Shared by verify-otp and driver registration so both issue the
   * same device-bound tokens. Returns the (possibly risk-updated) user.
   */
  private async bindDeviceForUser(
    user: UserEntity,
    device?: VerifyOtpDeviceDto,
  ): Promise<{
    user: UserEntity;
    deviceState: 'active' | 'revoked' | null;
    activeDeviceId: string | null;
  }> {
    if (!device) {
      return { user, deviceState: null, activeDeviceId: null };
    }

    const fingerprintHash = this.deviceFingerprintService.hash(
      device.platform,
      device.deviceId,
      device.installSalt,
    );

    // Check whether this fingerprint is explicitly revoked for this user
    const revokedDevice = await this.deviceFingerprintService[
      'deviceRepo'
    ].findOne({
      where: {
        userId: user.id,
        fingerprintHash,
        status: UserDeviceStatus.REVOKED,
      },
    });

    if (revokedDevice) {
      throw new UnauthorizedException(
        'This device has been revoked. Please use another trusted device.',
      );
    }

    // Register / refresh the device session
    const registeredDevice = await this.deviceFingerprintService.registerDevice(
      {
        userId: user.id,
        platform: device.platform,
        deviceId: device.deviceId,
        installSalt: device.installSalt,
        fcmToken: device.fcmToken,
        locale: device.locale,
        label: device.label,
      },
    );

    // Run multi-account risk check after device row exists
    await this.accountRiskService.checkMultiAccountThreshold(
      user.id,
      fingerprintHash,
    );

    // Reload user in case restricted flag was just set by risk service
    const refreshed = await this.usersService.findById(user.id);

    return {
      user: refreshed ?? user,
      deviceState: 'active',
      activeDeviceId: registeredDevice.id,
    };
  }

  private async generateTokens(
    user: UserEntity,
    deviceId: string | null = null,
  ): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      did: deviceId,
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

  private resolveAccountState(
    user: UserEntity,
  ): 'active' | 'restricted' | 'banned' {
    if (user.bannedAt) {
      return 'banned';
    }
    if (user.restricted) {
      return 'restricted';
    }
    return 'active';
  }

  private async findUserByPhoneWithPassword(
    phoneNumber: string,
  ): Promise<(UserEntity & { passwordHash: string | null }) | null> {
    return this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.phoneNumber = :phoneNumber', { phoneNumber })
      .getOne() as Promise<
      (UserEntity & { passwordHash: string | null }) | null
    >;
  }

  private async findAdminByEmailWithPassword(
    email: string,
  ): Promise<(UserEntity & { passwordHash: string | null }) | null> {
    return this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('LOWER(user.email) = LOWER(:email)', { email: email.trim() })
      .andWhere('user.role = :role', { role: PgUserRole.ADMIN })
      .getOne() as Promise<
      (UserEntity & { passwordHash: string | null }) | null
    >;
  }

  private async findUserByIdWithPassword(
    id: string,
  ): Promise<UserEntity & { passwordHash: string | null }> {
    const user = (await this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.passwordHash')
      .where('user.id = :id', { id })
      .getOne()) as (UserEntity & { passwordHash: string | null }) | null;

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return user;
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

  private async notifyAdminsOfNewUser(newUser: UserEntity): Promise<void> {
    const admins = await this.userRepo.find({
      where: { role: PgUserRole.ADMIN, isActive: true },
      select: ['id'],
    });
    if (admins.length === 0) return;

    const displayName =
      newUser.name && newUser.name.trim().length > 0
        ? newUser.name.trim()
        : (newUser.phoneNumber ?? newUser.email ?? 'New user');
    const title = 'New user registered';
    const body = `${displayName} just signed up as a ${newUser.role}.`;
    const data = {
      newUserId: newUser.id,
      role: newUser.role,
      phoneNumber: newUser.phoneNumber,
      email: newUser.email,
    };

    await Promise.all(
      admins.map((admin) =>
        this.notificationsService
          .create({
            userId: admin.id,
            type: 'new_user_registered',
            title,
            body,
            data,
          })
          .catch((err) => {
            this.logger.error(
              `Failed to deliver new-user notification to admin ${admin.id}: ${(err as Error).message}`,
            );
          }),
      ),
    );
  }
}
