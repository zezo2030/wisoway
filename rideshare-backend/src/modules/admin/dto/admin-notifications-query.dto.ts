import { IsOptional, IsString } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class AdminNotificationsQueryDto extends PaginationDto {
  @IsOptional()
  @IsString()
  type?: string;
}
