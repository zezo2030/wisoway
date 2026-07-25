import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  PassengerDeclaredStatus,
  SeatAbsenceReason,
} from '../../../database/entities/booking-seat.entity';

export class PresenceEntryDto {
  @ApiProperty()
  @IsUUID()
  bookingId: string;

  @ApiProperty()
  @IsString()
  seatNumber: string;

  @ApiProperty({
    description:
      'true = occupant was in the vehicle. false = explicitly absent, which is the ONLY way to make a seat non-billable.',
  })
  @IsBoolean()
  present: boolean;

  @ApiPropertyOptional({
    enum: Object.values(SeatAbsenceReason),
    description: 'Required in spirit when present=false; defaults to no_show.',
  })
  @IsOptional()
  @IsIn(Object.values(SeatAbsenceReason))
  reason?: SeatAbsenceReason;
}

export class DriverPresenceConfirmDto {
  @ApiProperty({ type: [PresenceEntryDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => PresenceEntryDto)
  entries: PresenceEntryDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  idempotencyKey?: string;
}

export class PassengerDeclareDto {
  @ApiProperty({ enum: Object.values(PassengerDeclaredStatus) })
  @IsIn(Object.values(PassengerDeclaredStatus))
  status: PassengerDeclaredStatus;

  @ApiPropertyOptional({
    description:
      'Seats this declaration applies to. Omit to apply to every seat in the booking (the main booker answering for companions).',
  })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  seatNumbers?: string[];
}
