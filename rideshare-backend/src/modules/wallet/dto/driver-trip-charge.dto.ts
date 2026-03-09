import { IsOptional, IsString } from 'class-validator';

export class DriverTripChargeDto {
  @IsString()
  tripId: string;

  @IsOptional()
  @IsString()
  idempotencyKey?: string;
}
