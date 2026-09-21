import { IsOptional, IsString } from 'class-validator';

export class PlaceDetailQueryDto {
  @IsOptional()
  @IsString()
  sessionToken?: string;
}

export interface PlaceDetailResponseDto {
  placeId: string;
  label: string;
  lat: number;
  lng: number;
}
