import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { BookingEntity } from '../../database/entities/booking.entity';
import { ShareLinksController } from './share-links.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([TripShareLinkEntity, TripEntity, BookingEntity]),
  ],
  controllers: [ShareLinksController],
  exports: [],
})
export class ShareLinksModule {}
