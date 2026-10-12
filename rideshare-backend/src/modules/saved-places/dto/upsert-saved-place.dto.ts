import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsLatitude,
  IsLongitude,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { SavedPlaceKind } from '../../../database/entities/saved-place.entity';

export class UpsertSavedPlaceDto {
  @ApiProperty({ enum: SavedPlaceKind, example: SavedPlaceKind.HOME })
  @IsEnum(SavedPlaceKind)
  kind: SavedPlaceKind;

  @ApiPropertyOptional({
    description:
      'Name of a custom place, unique per user. Ignored for home and work.',
    example: 'الجامعة',
  })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  label?: string;

  @ApiProperty({ example: 'Abdali Boulevard' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  name: string;

  @ApiPropertyOptional({ example: 'Amman, Jordan' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  secondaryText?: string;

  @ApiProperty({ example: 31.9634 })
  @IsLatitude()
  latitude: number;

  @ApiProperty({ example: 35.9106 })
  @IsLongitude()
  longitude: number;
}
