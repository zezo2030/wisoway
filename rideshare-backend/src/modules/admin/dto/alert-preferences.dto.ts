import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsEnum } from 'class-validator';
import { AdminAlertType } from '../../../database/entities/shared.enums';

export class UpdateAlertPreferenceDto {
  @ApiProperty({ enum: AdminAlertType })
  @IsEnum(AdminAlertType)
  alertType: AdminAlertType;

  @ApiProperty()
  @IsBoolean()
  enabled: boolean;
}
