import { registerAs } from '@nestjs/config';
import { IsString, validateSync } from 'class-validator';
import { plainToClass } from 'class-transformer';

class StripeConfig {
  @IsString()
  STRIPE_SECRET_KEY: string;

  @IsString()
  STRIPE_WEBHOOK_SECRET: string;
}

export const stripeConfig = registerAs('stripe', () => {
  const config = plainToClass(StripeConfig, {
    STRIPE_SECRET_KEY: process.env.STRIPE_SECRET_KEY || '',
    STRIPE_WEBHOOK_SECRET: process.env.STRIPE_WEBHOOK_SECRET || '',
  });

  const errors = validateSync(config);
  if (errors.length > 0 && process.env.NODE_ENV === 'production') {
    throw new Error(errors.toString());
  }

  return config;
});
