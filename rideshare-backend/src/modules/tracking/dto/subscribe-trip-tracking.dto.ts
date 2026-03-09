import { IsString } from 'class-validator';

export class SubscribeTripTrackingDto {
  @IsString()
  tripId: string;
}
