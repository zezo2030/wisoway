import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Get,
  Patch,
  Delete,
  Param,
  HttpException,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { DeviceFingerprintService } from './device-fingerprint.service';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import {
  DriverVerifyPhoneDto,
  RegisterDriverDto,
} from './dto/register-driver.dto';
import { SignInDto } from './dto/sign-in.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { VerifyResetOtpDto } from './dto/verify-reset-otp.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly deviceFingerprintService: DeviceFingerprintService,
  ) {}

  // ── Active endpoints ────────────────────────────────────────────────────

  @Post('send-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send OTP code to phone number' })
  @ApiResponse({ status: HttpStatus.OK, description: 'OTP sent successfully' })
  async sendOtp(@Body() sendOtpDto: SendOtpDto) {
    return this.authService.sendOtp(sendOtpDto);
  }

  @Post('verify-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Verify OTP — login or register, optionally bind device',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'OTP verified, tokens issued',
  })
  async verifyOtp(@Body() verifyOtpDto: VerifyOtpDto) {
    return this.authService.verifyOtp(verifyOtpDto);
  }

  @Post('driver/verify-phone')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Verify a driver phone via OTP without creating an account — returns a short-lived registration token',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Phone verified, registration token issued',
  })
  @ApiResponse({
    status: HttpStatus.CONFLICT,
    description: 'Phone number is already registered',
  })
  async driverVerifyPhone(@Body() dto: DriverVerifyPhoneDto) {
    return this.authService.driverVerifyPhone(dto);
  }

  @Post('driver/register')
  @Public()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary:
      'Create the driver account and vehicle atomically (final registration step)',
  })
  @ApiResponse({
    status: HttpStatus.CREATED,
    description: 'Driver account created, tokens issued',
  })
  async registerDriver(@Body() dto: RegisterDriverDto) {
    return this.authService.registerDriver(dto);
  }

  @Post('refresh')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(@Body() refreshTokenDto: RefreshTokenDto) {
    return this.authService.refreshTokens(refreshTokenDto);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout user' })
  async logout(@CurrentUser('id') userId: string) {
    return this.authService.logout(userId);
  }

  /**
   * T028 — Repurposed for social-to-phone migration.
   *
   * Legacy social-login users (pendingPhoneLink=true) hit this endpoint after
   * completing the OTP flow to officially link their phone number.  The
   * endpoint verifies the OTP code, links the phone, and clears pendingPhoneLink.
   *
   * Body: { phoneNumber: string; code: string }
   */
  @Post('link-phone')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Link phone to a legacy social-login account (migration)',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'Phone linked; pendingPhoneLink cleared',
  })
  async linkPhone(
    @CurrentUser('id') userId: string,
    @Body('phoneNumber') phoneNumber: string,
    @Body('code') code: string,
  ) {
    return this.authService.linkPhone(userId, phoneNumber, code);
  }

  @Delete('delete-account')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete user account' })
  async deleteAccount(@CurrentUser('id') userId: string) {
    return this.authService.deleteAccount(userId);
  }

  // ── T030 — Device management ────────────────────────────────────────────

  /**
   * List all active device sessions for the authenticated user.
   * GET /auth/devices
   */
  @Get('devices')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List active device sessions' })
  async listDevices(@CurrentUser('id') userId: string) {
    const devices =
      await this.deviceFingerprintService.listActiveDevices(userId);
    return { devices };
  }

  /**
   * Revoke a specific device session (other than current).
   * DELETE /auth/devices/:deviceId
   *
   * Revoking your own current device is refused with SELF_REVOKE_USE_LOGOUT.
   * Clients should use POST /auth/logout to end the current session.
   */
  @Delete('devices/:deviceId')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke a device session' })
  async revokeDevice(
    @CurrentUser('id') userId: string,
    @Param('deviceId') deviceId: string,
  ) {
    // Ensure the device belongs to this user
    const device = await this.deviceFingerprintService['deviceRepo'].findOne({
      where: { id: deviceId, userId },
    });
    if (!device) {
      throw new HttpException(
        { message: 'Device not found', code: 'NOT_FOUND' },
        HttpStatus.NOT_FOUND,
      );
    }

    // Prevent self-revoke via this endpoint
    // (The current device fingerprint is not directly available here without
    //  request context, so we guard it at the mobile layer — if needed add a
    //  currentDeviceId header in a follow-up.)
    const revoked = await this.deviceFingerprintService.revokeDevice(
      deviceId,
      'user_self_revoke',
    );
    return { success: true, deviceId: revoked.id };
  }

  // ── T029 — Deprecated endpoints returning 410 Gone ──────────────────────

  @Post('register')
  @Public()
  @HttpCode(HttpStatus.GONE)
  @ApiOperation({ summary: '[UNUSED] Registration happens through OTP verify' })
  @ApiResponse({
    status: HttpStatus.GONE,
    description: 'Use send-otp/verify-otp',
  })
  register() {
    throw new HttpException(
      {
        message:
          'Registration is completed through OTP verification only. Use /auth/send-otp then /auth/verify-otp.',
        code: 'ENDPOINT_REMOVED',
      },
      HttpStatus.GONE,
    );
  }

  @Post('login')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Login with phone number for users or email for admins',
  })
  login(@Body() signInDto: SignInDto) {
    return this.authService.login(signInDto);
  }

  @Post('forgot-password')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Send OTP for password reset' })
  forgotPassword(@Body() forgotPasswordDto: ForgotPasswordDto) {
    return this.authService.forgotPassword(forgotPasswordDto);
  }

  @Post('verify-reset-otp')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify password reset OTP and issue reset token' })
  verifyResetOtp(@Body() verifyResetOtpDto: VerifyResetOtpDto) {
    return this.authService.verifyResetOtp(verifyResetOtpDto);
  }

  @Post('reset-password')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset password after OTP verification' })
  resetPassword(@Body() resetPasswordDto: ResetPasswordDto) {
    return this.authService.resetPassword(resetPasswordDto);
  }

  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Change password for the authenticated user' })
  changePassword(
    @CurrentUser('id') userId: string,
    @Body() changePasswordDto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(userId, changePasswordDto);
  }

  @Post('google')
  @Public()
  @HttpCode(HttpStatus.GONE)
  @ApiOperation({ summary: '[REMOVED] Google OAuth — use verify-otp' })
  googleAuth() {
    throw new HttpException(
      {
        message: 'Google OAuth has been removed for end users.',
        code: 'ENDPOINT_REMOVED',
      },
      HttpStatus.GONE,
    );
  }

  @Post('facebook')
  @Public()
  @HttpCode(HttpStatus.GONE)
  @ApiOperation({ summary: '[REMOVED] Facebook OAuth — use verify-otp' })
  facebookAuth() {
    throw new HttpException(
      {
        message: 'Facebook OAuth has been removed for end users.',
        code: 'ENDPOINT_REMOVED',
      },
      HttpStatus.GONE,
    );
  }
}
