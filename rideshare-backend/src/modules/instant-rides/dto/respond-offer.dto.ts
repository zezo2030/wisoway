import { IsIn, IsNumber, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Instant fares are fixed by the platform, so a driver can only take the ride
 * at that fare or pass on it — the old 'counter' response is rejected.
 */
export const OfferResponseType = {
  ACCEPT: 'accept',
  DECLINE: 'decline',
} as const;
export type OfferResponseType =
  (typeof OfferResponseType)[keyof typeof OfferResponseType];

export class RespondOfferDto {
  @IsIn(Object.values(OfferResponseType))
  responseType: OfferResponseType;

  /** Ignored; accepted only so older apps that send it are not rejected. */
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount?: number;
}
