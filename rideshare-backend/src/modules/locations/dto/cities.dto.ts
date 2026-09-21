import { IsOptional, IsString, Length, Matches } from 'class-validator';

/** Query for `GET /locations/cities`, the city-first picker's catalog. */
export class CitiesQueryDto {
  /**
   * ISO 3166-1 alpha-2 filter. Omitted → every city in the configured
   * operating countries.
   */
  @IsOptional()
  @IsString()
  @Matches(/^[a-z]{2}$/i, { message: 'country must be an ISO alpha-2 code' })
  country?: string;

  /** Optional server-side filter; the app also filters the cached list. */
  @IsOptional()
  @IsString()
  @Length(1, 80)
  q?: string;
}

export interface CityDto {
  id: string;
  nameAr: string;
  nameEn: string;
  countryCode: string;
  lat: number;
  lng: number;
  /** Listed above the rest in the picker before the user types. */
  popular: boolean;
}

export interface CitiesResponseDto {
  cities: CityDto[];
}
