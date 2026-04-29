import { IsString, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class DriverConfirmDto {
  @ApiProperty({ description: 'Seat number to confirm presence for' })
  @IsString()
  seatNumber: string;

  @ApiProperty({
    description: 'Whether the passenger for this seat is present',
  })
  @IsBoolean()
  present: boolean;
}
