import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Module,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import {
  IsBoolean,
  IsIn,
  IsISO8601,
  IsNumber,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { Roles } from '../../common/decorators/roles.decorator';

export class CampaignDto {
  @Matches(/^[A-Za-z0-9_-]{3,32}$/) code: string;
  @IsNumber({ maxDecimalPlaces: 2 }) @Min(0.01) @Max(100) percent: number;
  @IsIn(['all', 'instant', 'shared']) tripType: string;
  @IsISO8601() startsAt: string;
  @IsISO8601() endsAt: string;
  @IsBoolean() active: boolean;
}
class PreviewDto {
  @IsString() @Matches(/^[A-Za-z0-9_-]{3,32}$/) code: string;
  @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) amount: number;
  @IsIn(['instant', 'shared']) tripType: string;
}
class ActiveDto {
  @IsBoolean() active: boolean;
}
type Campaign = {
  code: string;
  percent: string;
  tripType: string;
  active: boolean;
  startsAt: Date;
  endsAt: Date;
};

/** Recalculated on the server when booking; previews never authorize an amount. */
export async function pricePromotion(
  manager: EntityManager,
  code: string | undefined,
  amount: number,
  tripType: string,
) {
  const originalAmount = amount.toFixed(2);
  if (!code?.trim())
    return {
      originalAmount,
      totalAmount: originalAmount,
      discountAmount: '0.00',
      promoCode: null,
    };
  const normalized = code.trim().toUpperCase();
  const rows = await manager.query<Campaign[]>(
    'SELECT * FROM promotion_campaigns WHERE code=$1',
    [normalized],
  );
  const c = rows[0];
  const now = Date.now();
  if (
    !c ||
    !c.active ||
    new Date(c.startsAt).getTime() > now ||
    new Date(c.endsAt).getTime() <= now ||
    (c.tripType !== 'all' && c.tripType !== tripType)
  ) {
    throw new BadRequestException('كود الخصم غير صالح أو منتهي لهذه الرحلة.');
  }
  const cents = Math.round(amount * 100);
  const discount = Math.min(
    cents,
    Math.round((cents * Number(c.percent)) / 100),
  );
  return {
    originalAmount,
    totalAmount: ((cents - discount) / 100).toFixed(2),
    discountAmount: (discount / 100).toFixed(2),
    promoCode: normalized,
  };
}

@Controller('promotions')
class PromotionsController {
  constructor(private readonly db: DataSource) {}
  @Post('preview')
  preview(@Body() dto: PreviewDto) {
    return pricePromotion(this.db.manager, dto.code, dto.amount, dto.tripType);
  }
  @Get('admin')
  @Roles('admin')
  list() {
    return this.db.query(
      'SELECT * FROM promotion_campaigns ORDER BY "createdAt" DESC',
    );
  }
  @Post('admin')
  @Roles('admin')
  async create(@Body() dto: CampaignDto) {
    if (new Date(dto.endsAt) <= new Date(dto.startsAt))
      throw new BadRequestException('تاريخ النهاية يجب أن يلي البداية.');
    const rows = await this.db.query<Campaign[]>(
      `INSERT INTO promotion_campaigns (code,percent,"tripType","startsAt","endsAt",active) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (code) DO NOTHING RETURNING *`,
      [
        dto.code.toUpperCase(),
        dto.percent,
        dto.tripType,
        dto.startsAt,
        dto.endsAt,
        dto.active,
      ],
    );
    if (!rows.length) throw new BadRequestException('كود الخصم مستخدم بالفعل.');
    return rows[0];
  }
  @Patch('admin/:code')
  @Roles('admin')
  async toggle(@Param('code') code: string, @Body() dto: ActiveDto) {
    return this.db.query(
      'UPDATE promotion_campaigns SET active=$2 WHERE code=$1 RETURNING *',
      [code.toUpperCase(), dto.active],
    );
  }
}
@Module({ controllers: [PromotionsController] })
export class PromotionsModule {}
