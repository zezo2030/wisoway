import { IsBoolean, IsString } from 'class-validator';

export class SetSeatLockDto {
  @IsString()
  seatNumber: string;

  @IsBoolean()
  locked: boolean;
}
