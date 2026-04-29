import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';

/**
 * SupportController — T171 (Phase 8 / US6)
 *
 * GET /support/config
 *   Returns the WhatsApp support number and deep-link base so the mobile app
 *   and dashboard can fetch the configured number rather than hardcoding it.
 *   Cache-friendly — the values change only on deployment.
 */
@ApiTags('Support')
@Controller('support')
export class SupportController {
  /** T171 — Return WhatsApp config from env. */
  @Get('config')
  @Public()
  @ApiOperation({ summary: 'Get WhatsApp support config' })
  @ApiResponse({
    status: 200,
    schema: {
      type: 'object',
      properties: {
        whatsappE164: { type: 'string', example: '+962788883007' },
        whatsappDeepLinkBase: {
          type: 'string',
          example: 'https://wa.me/962788883007',
        },
      },
    },
  })
  getConfig(): { whatsappE164: string; whatsappDeepLinkBase: string } {
    const e164 = process.env.SUPPORT_WHATSAPP_E164 ?? '+962788883007';
    const number = e164.replace(/^\+/, '');
    return {
      whatsappE164: e164,
      whatsappDeepLinkBase: `https://wa.me/${number}`,
    };
  }
}
