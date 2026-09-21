import {
  IsString,
  IsNotEmpty,
  IsUUID,
  IsBoolean,
  IsOptional,
  IsArray,
  ValidateNested,
  ArrayMinSize,
  ArrayMaxSize,
  IsIn,
  MaxLength,
  IsInt,
  Min,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class BookingSeatDto {
  @ApiProperty({ example: '0-0' })
  @IsString()
  @IsNotEmpty()
  seatNumber: string;

  @ApiProperty({ example: 'Layla' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  displayName: string;

  @ApiProperty({ enum: ['male', 'female'] })
  @IsIn(['male', 'female'])
  gender: 'male' | 'female';

  @ApiProperty({ example: true })
  @IsBoolean()
  isMainBooker: boolean;
}

/**
 * A passenger in an auto-pick request.
 *
 * Auto-pick assigns the seat numbers itself, so this deliberately has no
 * `seatNumber`. `AutoPickBookingDto.passengers` used to be typed as
 * `Omit<BookingSeatDto, 'seatNumber'>[]` while still carrying
 * `@Type(() => BookingSeatDto)`, so validation ran against the full class and
 * rejected any request that left `seatNumber` out — the one field the endpoint
 * exists to compute. Callers had to send a dummy value that the service then
 * discarded.
 */
export class AutoPickPassengerDto {
  @ApiProperty({ example: 'Layla' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  displayName: string;

  @ApiProperty({ enum: ['male', 'female'] })
  @IsIn(['male', 'female'])
  gender: 'male' | 'female';

  @ApiProperty({ example: true })
  @IsBoolean()
  isMainBooker: boolean;

  /**
   * Ignored — auto-pick computes the seat number. Accepted only so existing
   * clients that reuse their multi-seat payload keep working.
   */
  @ApiPropertyOptional({ deprecated: true })
  @IsOptional()
  @IsString()
  seatNumber?: string;
}

export class CreateMultiSeatBookingDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  tripId: string;

  @ApiProperty({ type: [BookingSeatDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => BookingSeatDto)
  seats: BookingSeatDto[];

  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  sharePhoneWithDriver?: boolean;

  /**
   * Family booking — exempts this request from the trip's prevent-gender-mixing
   * rules. Requires at least 2 seats.
   */
  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  isFamilyBooking?: boolean;
}

export class AutoPickBookingDto {
  @ApiProperty({ example: '123e4567-e89b-12d3-a456-426614174000' })
  @IsUUID()
  tripId: string;

  @ApiProperty({ example: 2 })
  @IsInt()
  @Min(1)
  @Max(50)
  seatCount: number;

  @ApiProperty({ type: [AutoPickPassengerDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => AutoPickPassengerDto)
  passengers: AutoPickPassengerDto[];

  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  sharePhoneWithDriver?: boolean;

  /**
   * Family booking — exempts this request from the trip's prevent-gender-mixing
   * rules (both during auto-selection and on the resulting booking).
   * Requires at least 2 seats.
   */
  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  isFamilyBooking?: boolean;
}
