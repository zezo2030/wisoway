import {
  IsString,
  IsInt,
  IsOptional,
  IsBoolean,
  IsArray,
  ArrayMaxSize,
  MaxLength,
  Min,
  Max,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class VehicleSeatLayoutDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  rows: number;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  seatsPerRow: number;

  @IsOptional()
  @IsBoolean()
  preventGenderMixing?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @IsInt({ each: true })
  @Min(1, { each: true })
  @Max(10, { each: true })
  seatsPerRowList?: number[];
}

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

  // Optional: when omitted the seat count is derived automatically from the
  // selected vehicle type's seat layout (see VehiclesService.create).
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(50)
  seats?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => VehicleSeatLayoutDto)
  seatLayout?: VehicleSeatLayoutDto;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  licenseImageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  vehicleLicenseImageUrl?: string;

  @IsString()
  @MaxLength(500)
  carImageUrl: string;
}
