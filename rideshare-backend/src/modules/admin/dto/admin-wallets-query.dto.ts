import { IsOptional, IsEnum, IsString } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import {
  PgUserRole,
  WalletAccountType,
} from '../../../database/entities/shared.enums';

export class AdminWalletsQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum([PgUserRole.DRIVER, PgUserRole.PASSENGER])
  role?: PgUserRole.DRIVER | PgUserRole.PASSENGER;

  @IsOptional()
  @IsEnum([WalletAccountType.DRIVER, WalletAccountType.RIDER])
  accountType?: WalletAccountType.DRIVER | WalletAccountType.RIDER;

  @IsOptional()
  @IsString()
  search?: string;
}

