import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class AdminChatQueryDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'Filter rooms by trip ID' })
  @IsOptional()
  @IsString()
  tripId?: string;
}
