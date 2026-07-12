import { registerAs } from '@nestjs/config';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  validateSync,
} from 'class-validator';
import { plainToClass, Transform } from 'class-transformer';

/**
 * Test-override and feature-flag configuration for time-window-driven flows.
 *
 * All values are read once at boot from environment variables and exposed via
 * NestJS ConfigService under the `platform` namespace:
 *   configService.get<PlatformConfig>('platform')
 *
 * In production these env vars are simply absent; the defaults listed here
 * keep the production behaviour unchanged.  In integration tests (and the
 * quickstart runbook) individual overrides are set to collapse wait times.
 */
class PlatformConfig {
  /**
   * Override the 3-hour pending-booking timeout (seconds).
   * Default: undefined → 10 800 s (3 h) used by the processor.
   */
  @IsInt()
  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined && value !== '' ? parseInt(value, 10) : undefined,
  )
  BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS?: number;

  /**
   * Override the 30-minute driver no-show grace period (seconds).
   * Default: undefined → 1 800 s (30 min) used by the processor.
   */
  @IsInt()
  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined && value !== '' ? parseInt(value, 10) : undefined,
  )
  NO_SHOW_GRACE_OVERRIDE_SECONDS?: number;

  /**
   * Override the pre-trip confirmation offset before departure (seconds).
   * Default: undefined → 1 800 s (30 min) used by the processor.
   */
  @IsInt()
  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined && value !== '' ? parseInt(value, 10) : undefined,
  )
  PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS?: number;

  /**
   * When truthy, OTP verification accepts any 6-digit code without contacting
   * Twilio.  Must never be set in production.
   * Default: false.
   */
  @IsBoolean()
  @Transform(({ value }) => value === '1' || value === 'true' || value === true)
  OTP_DEV_BYPASS: boolean;

  /**
   * Settlement grace window in seconds; after this the driver can no longer
   * unsettle a booking via the API.
   * Default: 300 s (5 min).
   */
  @IsInt()
  @Transform(({ value }) =>
    value !== undefined && value !== '' ? parseInt(value, 10) : 300,
  )
  SETTLEMENT_GRACE_SECONDS: number;

  /**
   * Minimum mobile app version allowed to call the API (Phase 9 / T180).
   * Requests from app versions below this string are rejected with
   * 409 UPGRADE_REQUIRED before reaching any endpoint.
   *
   * Format: semver string, e.g. "2.4.0"
   * Default: undefined → version gate disabled (safe default during rollout).
   *
   * Set this to the first app version that recognises `status='published'`
   * once that version has reached sufficient market penetration.
   */
  @IsString()
  @IsOptional()
  MIN_APP_VERSION?: string;

  /**
   * Server-side Google Places key used by the backend autocomplete proxy.
   * Default: undefined -> locations autocomplete is unavailable until configured.
   */
  @IsString()
  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined && value !== '' ? String(value) : undefined,
  )
  GOOGLE_PLACES_API_KEY?: string;

  /**
   * Firebase Web sender id used to document/verify the dashboard FCM web setup.
   * Push delivery still uses the existing Firebase Admin credentials.
   */
  @IsString()
  @IsOptional()
  @Transform(({ value }) =>
    value !== undefined && value !== '' ? String(value) : undefined,
  )
  FIREBASE_WEB_MESSAGING_SENDER_ID?: string;
}

export const platformConfig = registerAs('platform', () => {
  const config = plainToClass(PlatformConfig, {
    BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS:
      process.env.BOOKINGS_TIMEOUT_TEST_OVERRIDE_SECONDS,
    NO_SHOW_GRACE_OVERRIDE_SECONDS: process.env.NO_SHOW_GRACE_OVERRIDE_SECONDS,
    PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS:
      process.env.PRE_TRIP_CONFIRM_OFFSET_OVERRIDE_SECONDS,
    OTP_DEV_BYPASS: process.env.OTP_DEV_BYPASS,
    SETTLEMENT_GRACE_SECONDS: process.env.SETTLEMENT_GRACE_SECONDS,
    MIN_APP_VERSION: process.env.MIN_APP_VERSION,
    GOOGLE_PLACES_API_KEY: process.env.GOOGLE_PLACES_API_KEY,
    FIREBASE_WEB_MESSAGING_SENDER_ID:
      process.env.FIREBASE_WEB_MESSAGING_SENDER_ID,
  });

  const errors = validateSync(config, { skipMissingProperties: true });
  if (errors.length > 0) {
    throw new Error(
      `Platform configuration validation failed: ${errors.toString()}`,
    );
  }

  return config;
});
