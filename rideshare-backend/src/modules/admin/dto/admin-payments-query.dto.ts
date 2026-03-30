import { IsOptional, IsEnum, IsBoolean } from 'class-validator';
import { Transform } from 'class-transformer';
import { PaginationDto } from '../../../common/dto/pagination.dto';

export class AdminPaymentsQueryDto extends PaginationDto {
  @IsOptional()
  @IsEnum(['pending', 'approved', 'rejected', 'refunded'])
  status?: string;

  @IsOptional()
  @IsEnum(['wallet', 'paymob', 'manual', 'communication_fee'])
  method?: string;

  @IsOptional()
  @IsEnum(['trip', 'communication_fee', 'wallet_topup', 'wallet_trip_charge'])
  paymentType?: string;

  @IsOptional()
  @Transform(({ value }) => {
    if (value === 'true') return true;
    if (value === 'false') return false;
    return value;
  })
  @IsBoolean()
  walletOnly?: boolean;
}
