import { IsOptional, IsEnum, IsString } from 'class-validator';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class AdminTripsQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(['active', 'hidden', 'completed', 'cancelled'])
  status?: string;

  @IsOptional()
  @IsString()
  driverId?: string;
}
