import { registerAs } from '@nestjs/config';
import { IsString, validateSync } from 'class-validator';
import { plainToClass } from 'class-transformer';

class A2aCliqConfig {
  @IsString()
  BASE_URL: string;

  @IsString()
  MERCHANT_ID: string;

  @IsString()
  USER_ID: string;

  @IsString()
  PASSWORD: string;

  @IsString()
  SECURITY_KEY: string;

  @IsString()
  CORRELATION_ID: string;

  @IsString()
  BEARER_TOKEN: string;

  @IsString()
  CALLBACK_URL: string;
}

export const a2aCliqConfig = registerAs('a2aCliq', () => {
  const config = plainToClass(A2aCliqConfig, {
    BASE_URL:
      process.env.A2A_CLIQ_BASE_URL ||
      'https://testapi.uwallet.jo/A2AMerchantInterface',
    MERCHANT_ID: process.env.A2A_CLIQ_MERCHANT_ID || '',
    USER_ID: process.env.A2A_CLIQ_USER_ID || '',
    PASSWORD: process.env.A2A_CLIQ_PASSWORD || '',
    SECURITY_KEY: process.env.A2A_CLIQ_SECURITY_KEY || '',
    CORRELATION_ID: process.env.A2A_CLIQ_CORRELATION_ID || '',
    BEARER_TOKEN: process.env.A2A_CLIQ_BEARER_TOKEN || '',
    CALLBACK_URL:
      process.env.A2A_CLIQ_CALLBACK_URL ||
      'https://example.com/api/v1/payments/cliq/callback',
  });

  const errors = validateSync(config);
  if (errors.length > 0 && process.env.NODE_ENV === 'production') {
    throw new Error(errors.toString());
  }

  return config;
});
