import {
  IsIn,
  IsNumberString,
  IsOptional,
  IsString,
  Length,
  Matches,
} from 'class-validator';
import { Transform } from 'class-transformer';

/**
 * Trim incoming query strings before validation so a whitespace-only `q`
 * fails `Length` instead of reaching the provider.
 */
const trim = () =>
  Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  );

export class LocationAutocompleteQueryDto {
  @trim()
  @IsString()
  @Length(2, 200)
  q!: string;

  @IsOptional()
  @IsIn(['ar', 'en'])
  lang?: 'ar' | 'en';

  @IsOptional()
  @IsString()
  @Length(1, 64)
  sessionToken?: string;

  /** Search-context latitude. Must be sent together with `lng`. */
  @IsOptional()
  @IsNumberString()
  lat?: string;

  /** Search-context longitude. Must be sent together with `lat`. */
  @IsOptional()
  @IsNumberString()
  lng?: string;

  /**
   * Restricts and biases results to a city from `GET /locations/cities`.
   * Used by the city-first flow when creating a driver trip.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[a-z0-9_-]{1,40}$/i, {
    message: 'cityId must be a city catalog identifier',
  })
  cityId?: string;
}

export interface PlaceSuggestionDto {
  placeId: string;
  primaryText: string;
  secondaryText: string;
  description: string;
  /**
   * Straight-line metres from the request's search context (`lat`/`lng`, or the
   * city centre when only `cityId` is sent). Null when no context was supplied.
   * Rendered as the trailing distance label on each suggestion row.
   */
  distanceMeters: number | null;
}

export interface LocationAutocompleteResponseDto {
  sessionToken: string;
  suggestions: PlaceSuggestionDto[];
}
