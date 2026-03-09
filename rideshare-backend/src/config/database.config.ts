import { registerAs } from '@nestjs/config';
import {
  IsBooleanString,
  IsNumberString,
  IsOptional,
  IsString,
  validateSync,
} from 'class-validator';
import { plainToClass } from 'class-transformer';

class DatabaseConfig {
  @IsString()
  @IsOptional()
  MONGODB_URI?: string;

  @IsString()
  @IsOptional()
  POSTGRES_HOST?: string;

  @IsNumberString()
  @IsOptional()
  POSTGRES_PORT?: string;

  @IsString()
  @IsOptional()
  POSTGRES_USER?: string;

  @IsString()
  @IsOptional()
  POSTGRES_PASSWORD?: string;

  @IsString()
  @IsOptional()
  POSTGRES_DB?: string;

  @IsBooleanString()
  @IsOptional()
  POSTGRES_SSL?: string;
}

export const databaseConfig = registerAs('database', () => {
  const config = plainToClass(DatabaseConfig, {
    MONGODB_URI: process.env.MONGODB_URI,
    POSTGRES_HOST: process.env.POSTGRES_HOST || 'localhost',
    POSTGRES_PORT: process.env.POSTGRES_PORT || '5432',
    POSTGRES_USER: process.env.POSTGRES_USER || 'postgres',
    POSTGRES_PASSWORD: process.env.POSTGRES_PASSWORD || 'postgres',
    POSTGRES_DB: process.env.POSTGRES_DB || 'rideshare',
    POSTGRES_SSL: process.env.POSTGRES_SSL || 'false',
  });

  const errors = validateSync(config);
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }

  return config;
});
