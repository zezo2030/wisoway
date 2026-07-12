import { IsIn, IsNumberString, IsOptional, IsString } from 'class-validator';

export class LocationAutocompleteQueryDto {
  @IsString()
  q!: string;

  @IsOptional()
  @IsIn(['ar', 'en'])
  lang?: 'ar' | 'en';

  @IsOptional()
  @IsString()
  sessionToken?: string;

  @IsOptional()
  @IsNumberString()
  lat?: string;

  @IsOptional()
  @IsNumberString()
  lng?: string;
}

export interface PlaceSuggestionDto {
  placeId: string;
  primaryText: string;
  secondaryText: string;
  description: string;
}

export interface LocationAutocompleteResponseDto {
  sessionToken: string;
  suggestions: PlaceSuggestionDto[];
}
