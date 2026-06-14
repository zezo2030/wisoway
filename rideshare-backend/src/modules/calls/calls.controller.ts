import {
  Controller,
  Post,
  Param,
  Body,
  Req,
  HttpCode,
  HttpStatus,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CallsService } from './calls.service';
import type { Request } from 'express';
import { ConfigService } from '@nestjs/config';
import twilio from 'twilio';

@Controller()
export class CallsController {
  private readonly logger = new Logger(CallsController.name);

  constructor(
    private readonly callsService: CallsService,
    private readonly configService: ConfigService,
  ) {}

  /** POST /bookings/:id/calls/initiate — authenticated participant */
  @Post('bookings/:id/calls/initiate')
  @HttpCode(HttpStatus.CREATED)
  async initiate(
    @Param('id') bookingId: string,
    @CurrentUser('id') callerId: string,
  ) {
    return this.callsService.initiate(bookingId, callerId);
  }

  /**
   * POST /calls/twilio-webhook — public endpoint, validated with Twilio signature.
   *
   * Twilio posts call status updates here.  We verify the X-Twilio-Signature
   * header before processing to prevent spoofed webhooks.
   */
  @Public()
  @Post('calls/twilio-webhook')
  @HttpCode(HttpStatus.OK)
  async twilioWebhook(
    @Req() req: Request,
    @Body() body: Record<string, string>,
  ) {
    const authToken =
      this.configService.get<string>('twilio.TWILIO_AUTH_TOKEN') ?? '';

    const signature = (req.headers['x-twilio-signature'] as string) ?? '';
    const url = `${req.protocol}://${req.get('host')}${req.originalUrl}`;

    const isValid = twilio.validateRequest(authToken, signature, url, body);
    if (!isValid) {
      this.logger.warn('Rejected Twilio webhook: invalid signature');
      throw new ForbiddenException('Invalid Twilio signature');
    }

    await this.callsService.handleTwilioWebhook(body);
    return { received: true };
  }
}
