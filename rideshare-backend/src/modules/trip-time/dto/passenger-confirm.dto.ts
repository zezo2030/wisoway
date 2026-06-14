import { IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class PassengerConfirmDto {
  @ApiProperty({
    description: 'Whether the driver is present at the meeting point',
  })
  @IsBoolean()
  driverPresent: boolean;
}
