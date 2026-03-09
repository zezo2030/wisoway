import { IsString, IsOptional, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CancelBookingDto {
  @ApiProperty({
    description: 'The reason for cancelling the booking',
    example: 'Changed my mind',
    required: false,
  })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  reason?: string;
}
