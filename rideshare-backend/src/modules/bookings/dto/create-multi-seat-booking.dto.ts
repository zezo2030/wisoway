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

  @ApiProperty({ type: [BookingSeatDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => BookingSeatDto)
  passengers: Omit<BookingSeatDto, 'seatNumber'>[];

  @ApiPropertyOptional({ example: false })
  @IsBoolean()
  @IsOptional()
  sharePhoneWithDriver?: boolean;
}
