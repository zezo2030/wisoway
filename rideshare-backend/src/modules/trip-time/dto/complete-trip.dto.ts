import {
  IsArray,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class NoShowSeatEntry {
  @ApiProperty()
  @IsUUID()
  bookingId: string;

  @ApiProperty()
  @IsString()
  seatNumber: string;
}

export class CompleteTripDto {
  @ApiProperty({
    description: 'Seats where the passenger was a no-show',
    required: false,
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => NoShowSeatEntry)
  noShowSeats?: NoShowSeatEntry[];
}
