import {
  IsOptional,
  IsEnum,
  IsString,
  IsBoolean,
  IsNumber,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { WalletAccountType } from '../../../database/entities/shared.enums';

export class AdminWalletsQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(WalletAccountType)
  accountType?: WalletAccountType;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  minBalance?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  maxBalance?: number;

  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  isActive?: boolean;
}
