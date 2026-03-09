import {
  IsString,
  IsInt,
  IsOptional,
  MaxLength,
  Min,
  Max,
} from 'class-validator';

export class CreateVehicleDto {
  @IsString()
  @MaxLength(100)
  vehicleType: string;

  @IsString()
  @MaxLength(20)
  plateNumber: string;

  @IsString()
  @MaxLength(100)
  model: string;

  @IsInt()
  @Min(1)
  @Max(50)
  seats: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  licenseImageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  vehicleLicenseImageUrl?: string;
}
