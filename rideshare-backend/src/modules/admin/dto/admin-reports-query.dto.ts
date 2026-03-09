import { IsEnum, IsDateString } from 'class-validator';

export class AdminReportsQueryDto {
  @IsEnum(['revenue', 'users', 'trips'])
  type: 'revenue' | 'users' | 'trips';

  @IsDateString()
  startDate: string;

  @IsDateString()
  endDate: string;
}
