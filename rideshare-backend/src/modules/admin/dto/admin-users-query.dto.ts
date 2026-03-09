import { IsOptional, IsEnum, IsString, IsBoolean } from 'class-validator';
import { Transform } from 'class-transformer';
import { PaginationDto } from '../../../common/dto/pagination.dto';
import { PgUserRole } from '../../../database/entities/shared.enums';

export class AdminUsersQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(PgUserRole)
  role?: PgUserRole;

  @IsOptional()
  @IsString()
  search?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  isActive?: boolean;
}
