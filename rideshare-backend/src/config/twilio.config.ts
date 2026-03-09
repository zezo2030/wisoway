import { registerAs } from '@nestjs/config';
import { IsString, validateSync } from 'class-validator';
import { plainToClass } from 'class-transformer';

class TwilioConfig {
  @IsString()
  TWILIO_ACCOUNT_SID: string;

  @IsString()
  TWILIO_AUTH_TOKEN: string;

  @IsString()
  TWILIO_PHONE_NUMBER: string;

  @IsString()
  TWILIO_VERIFY_SERVICE_SID: string;

  @IsString()
  TWILIO_API_KEY_SID: string;

  @IsString()
  TWILIO_API_KEY_SECRET: string;
}

export const twilioConfig = registerAs('twilio', () => {
  const config = plainToClass(TwilioConfig, {
    TWILIO_ACCOUNT_SID: process.env.TWILIO_ACCOUNT_SID || '',
    TWILIO_AUTH_TOKEN: process.env.TWILIO_AUTH_TOKEN || '',
    TWILIO_PHONE_NUMBER: process.env.TWILIO_PHONE_NUMBER || '',
    TWILIO_VERIFY_SERVICE_SID: process.env.TWILIO_VERIFY_SERVICE_SID || '',
    TWILIO_API_KEY_SID: process.env.TWILIO_API_KEY_SID || '',
    TWILIO_API_KEY_SECRET: process.env.TWILIO_API_KEY_SECRET || '',
  });

  const errors = validateSync(config);
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }

  return config;
});
