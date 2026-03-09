import { IsString, IsOptional } from 'class-validator';

export class SocialLoginDto {
  @IsOptional()
  @IsString()
  idToken?: string; // Google OAuth ID token

  @IsOptional()
  @IsString()
  accessToken?: string; // Facebook access token
}
