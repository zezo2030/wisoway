import { registerAs } from '@nestjs/config';
import { IsString, IsInt, validateSync } from 'class-validator';
import { plainToClass, Transform } from 'class-transformer';

class RedisConfig {
  @IsString()
  REDIS_HOST: string;

  @IsInt()
  @Transform(({ value }) => parseInt(value, 10))
  REDIS_PORT: number;
}

export const redisConfig = registerAs('redis', () => {
  const config = plainToClass(RedisConfig, {
    REDIS_HOST: process.env.REDIS_HOST || 'localhost',
    REDIS_PORT: process.env.REDIS_PORT || 6379,
  });

  const errors = validateSync(config);
  if (errors.length > 0) {
    throw new Error(errors.toString());
  }

  return config;
});
