import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  Request,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  IsDecimal,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { RefundsService } from './refunds.service';

export class CreateRefundRequestBodyDto {
  @IsUUID()
  @IsOptional()
  bookingId?: string;

  @IsOptional()
  @IsDecimal()
  amount?: string;

  @IsString()
  @IsOptional()
  @IsIn(['JOD', 'USD', 'EUR'])
  currency?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  reason: string;
}

/**
 * RefundsController — T169 (Phase 8 / US6)
 *
 * POST /refund-requests — passenger files a refund request.
 *   Creates a DB row and returns a WhatsApp deep-link with prefilled context.
 */
@ApiTags('Refunds')
@ApiBearerAuth()
@Controller('refund-requests')
export class RefundsController {
  constructor(private readonly refundsService: RefundsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Submit a refund request' })
  @ApiBody({ type: CreateRefundRequestBodyDto })
  @ApiResponse({
    status: 201,
    schema: {
      type: 'object',
      properties: {
        refundRequest: { type: 'object' },
        whatsappDeepLink: {
          type: 'string',
          example: 'https://wa.me/962788883007?text=...',
        },
      },
    },
  })
  async create(@Request() req, @Body() dto: CreateRefundRequestBodyDto) {
    return this.refundsService.create(req.user.id, dto);
  }
}
