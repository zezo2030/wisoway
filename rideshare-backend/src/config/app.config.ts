import { registerAs } from '@nestjs/config';
import { IsInt, IsString, validateSync } from 'class-validator';
import { plainToClass, Transform } from 'class-transformer';

class AppConfig {
  @IsString()
  NODE_ENV: string;

  @IsInt()
  @Transform(({ value }) => parseInt(value, 10))
  PORT: number;

  @IsString()
  API_PREFIX: string;
}

export const appConfig = registerAs('app', () => {
  const config = plainToClass(AppConfig, {
    NODE_ENV: process.env.NODE_ENV || 'development',
    PORT: process.env.PORT || 3000,
    API_PREFIX: process.env.API_PREFIX || 'api/v1',
  });

  const errors = validateSync(config);
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }

  return config;
});
