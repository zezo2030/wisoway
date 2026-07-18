import { IsIn, IsNumber, IsOptional, Min } from 'class-validator';
import { Type } from 'class-transformer';

export const OfferResponseType = {
  /** Accept the ride at the passenger's fare. */
  ACCEPT: 'accept',
  /** Propose a higher fare; the passenger must accept it. */
  COUNTER: 'counter',
  DECLINE: 'decline',
} as const;
export type OfferResponseType =
  (typeof OfferResponseType)[keyof typeof OfferResponseType];

export class RespondOfferDto {
  @IsIn(Object.values(OfferResponseType))
  responseType: OfferResponseType;

  /** Required when responseType = counter. */
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  amount?: number;
}
