import { IsIn, IsNumberString, IsOptional } from 'class-validator';

/**
 * Query for `GET /locations/reverse`, the point-to-address lookup behind the
 * map picker's centre pin. Replaces the on-device geocoder so the label matches
 * the search provider's naming and the app's language.
 */
export class ReverseGeocodeQueryDto {
  @IsNumberString()
  lat!: string;

  @IsNumberString()
  lng!: string;

  @IsOptional()
  @IsIn(['ar', 'en'])
  lang?: 'ar' | 'en';
}

export interface ReverseGeocodeResponseDto {
  /** Street + number, or the nearest landmark. Empty when nothing was found. */
  primaryText: string;
  /** District, city and country, deduplicated against `primaryText`. */
  secondaryText: string;
  /** `primaryText` and `secondaryText` joined; the value stored on the trip. */
  label: string;
  lat: number;
  lng: number;
}
