import {
  IsString,
  IsNotEmpty,
  IsInt,
  Min,
  Max,
  IsOptional,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateRatingDto {
  @ApiProperty({
    description: 'User ID to rate',
    example: '507f1f77bcf86cd799439011',
  })
  @IsString()
  @IsNotEmpty()
  toUserId: string;

  @ApiProperty({ description: 'Trip ID', example: '507f1f77bcf86cd799439012' })
  @IsString()
  @IsNotEmpty()
  tripId: string;

  @ApiProperty({
    description: 'Rating value',
    example: 5,
    minimum: 1,
    maximum: 5,
  })
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @ApiPropertyOptional({
    description: 'Comment',
    maxLength: 500,
    example: 'Great driver!',
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  comment?: string;
}
