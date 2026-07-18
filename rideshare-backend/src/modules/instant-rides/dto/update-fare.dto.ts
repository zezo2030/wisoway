import { IsNumber, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateFareDto {
  /** The new (higher) total fare the passenger offers. */
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  passengerFare: number;
}
