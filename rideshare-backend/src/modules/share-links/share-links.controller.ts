import {
  Controller,
  Get,
  Post,
  Param,
  UseGuards,
  Req,
  Logger,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import type { Request } from 'express';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { Public } from '../../common/decorators/public.decorator';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { BookingStatus } from '../../database/entities/booking.entity';
import { TripStatus } from '../../database/entities/shared.enums';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { randomBytes } from 'crypto';

@ApiTags('share-links')
@Controller()
export class ShareLinksController {
  private readonly logger = new Logger(ShareLinksController.name);

  constructor(
    @InjectRepository(TripShareLinkEntity)
    private shareLinkRepo: Repository<TripShareLinkEntity>,
    @InjectRepository(TripEntity)
    private tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
  ) {}

  @Post('trips/:id/share-link')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a public share link for a trip' })
  async createShareLink(@Param('id') tripId: string, @Req() req: Request) {
    const user = req.user as Record<string, unknown> | undefined;
    const userId = (user?.id ?? user?.sub) as string | undefined;
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      return { statusCode: 404, message: 'Trip not found' };
    }

    const isDriver = trip.driverId === userId;
    let isConfirmedPassenger = false;
    if (!isDriver) {
      const booking = await this.bookingRepo.findOne({
        where: {
          tripId,
          userId,
          status: BookingStatus.CONFIRMED,
        },
      });
      isConfirmedPassenger = !!booking;
    }

    if (!isDriver && !isConfirmedPassenger) {
      return {
        statusCode: 403,
        message:
          'Only the driver or a confirmed passenger can create a share link',
      };
    }

    const token = randomBytes(32).toString('base64url');
    const expiresAt = new Date(
      new Date(trip.departureTime).getTime() + 6 * 60 * 60 * 1000,
    );

    const link = this.shareLinkRepo.create({
      tripId,
      createdByUserId: userId!,
      token,
      expiresAt,
    });
    const saved = await this.shareLinkRepo.save(link);

    return {
      url: `/share/${saved.token}`,
      token: saved.token,
      expiresAt: saved.expiresAt,
    };
  }

  @Get('share/:token')
  @Public()
  @ApiOperation({ summary: 'Public read-only trip status via share link' })
  async getPublicShare(@Param('token') token: string) {
    const link = await this.shareLinkRepo.findOne({
      where: { token },
      relations: ['trip'],
    });

    if (!link) {
      return { statusCode: 404, message: 'Share link not found' };
    }

    if (new Date() > new Date(link.expiresAt)) {
      return { statusCode: 410, message: 'Share link has expired' };
    }

    const trip = link.trip;

    const response: Record<string, unknown> = {
      tripStatus: trip.status,
      fromName: trip.fromName,
      toName: trip.toName,
      departureTime: trip.departureTime,
      etaMinutes: null,
      driverLocation: null,
    };

    if (trip.status === TripStatus.IN_PROGRESS) {
      if (
        trip.lastDriverLocationLat != null &&
        trip.lastDriverLocationLng != null
      ) {
        response.driverLocation = {
          lat: trip.lastDriverLocationLat,
          lng: trip.lastDriverLocationLng,
          capturedAt: trip.lastDriverLocationAt,
        };
      }
    }

    return response;
  }
}
