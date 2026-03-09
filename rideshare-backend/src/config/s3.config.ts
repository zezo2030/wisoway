import { registerAs } from '@nestjs/config';
import { IsString, validateSync } from 'class-validator';
import { plainToClass } from 'class-transformer';

class S3Config {
  @IsString()
  AWS_ACCESS_KEY_ID: string;

  @IsString()
  AWS_SECRET_ACCESS_KEY: string;

  @IsString()
  AWS_S3_BUCKET: string;

  @IsString()
  AWS_REGION: string;
}

export const s3Config = registerAs('s3', () => {
  const config = plainToClass(S3Config, {
    AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID || '',
    AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY || '',
    AWS_S3_BUCKET: process.env.AWS_S3_BUCKET || 'rideshare-uploads',
    AWS_REGION: process.env.AWS_REGION || 'me-south-1',
  });

  const errors = validateSync(config);
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }

  return config;
});
