import { IsString, IsNotEmpty, IsMongoId } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateBookingDto {
  @ApiProperty({
    description: 'The ID of the trip to book',
    example: '507f1f77bcf86cd799439011',
  })
  @IsString()
  @IsNotEmpty()
  @IsMongoId()
  tripId: string;

  @ApiProperty({
    description: 'The seat number to book (format: row-col, e.g., "0-0")',
    example: '0-0',
  })
  @IsString()
  @IsNotEmpty()
  seatNumber: string;
}
