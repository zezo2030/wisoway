import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, In, IsNull, Repository } from 'typeorm';
import { TripEntity } from '../database/entities/trip.entity';
import {
  BookingEntity,
  BookingStatus,
} from '../database/entities/booking.entity';
import { TripStatus, TripType } from '../database/entities/shared.enums';
import { NotificationsService } from '../modules/notifications/notifications.service';

/** How long before departure the driver and passengers are reminded. */
export const PRE_TRIP_REMINDER_LEAD_MS = 60 * 60 * 1000;

/**
 * One-hour reminder for shared (scheduled) trips, to the driver and every
 * confirmed passenger. It doubles as the presence prompt: the passenger's
 * notification opens presence confirmation, the driver's the passenger roster.
 *
 * The `pre-trip-confirm` queue this used to hang off was never fed a job, so no
 * reminder had ever gone out. A minute sweep needs no per-trip scheduling and
 * survives trips whose departure time is edited.
 */
@Injectable()
export class PreTripReminderJob {
  private readonly logger = new Logger(PreTripReminderJob.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    private readonly notificationsService: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async sweep(now: Date = new Date()): Promise<number> {
    const due = await this.tripRepo.find({
      where: {
        tripType: TripType.SCHEDULED,
        status: In([
          TripStatus.PUBLISHED,
          TripStatus.FULLY_BOOKED,
          TripStatus.ACTIVE,
        ]),
        departureTime: Between(
          now,
          new Date(now.getTime() + PRE_TRIP_REMINDER_LEAD_MS),
        ),
        preTripConfirmSentAt: IsNull(),
      },
      select: ['id'],
    });

    let sent = 0;
    for (const { id } of due) {
      if (await this.remind(id)) sent++;
    }
    if (sent > 0)
      this.logger.log(`Sent pre-trip reminders for ${sent} trip(s)`);
    return sent;
  }

  /** Sends the reminders for one trip, at most once. Returns whether it sent. */
  async remind(tripId: string): Promise<boolean> {
    // Claim first: only one instance (or one overlapping tick) gets to send.
    const claim = await this.tripRepo
      .createQueryBuilder()
      .update(TripEntity)
      .set({ preTripConfirmSentAt: () => 'NOW()' })
      .where('id = :tripId', { tripId })
      .andWhere('"preTripConfirmSentAt" IS NULL')
      .execute();
    if (!claim.affected) return false;

    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) return false;

    const bookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.CONFIRMED },
    });

    for (const booking of bookings) {
      const ar =
        (await this.notificationsService.getPreferredLocale(booking.userId)) ===
        'ar';
      await this.notificationsService
        .create({
          userId: booking.userId,
          type: 'presence_prompt',
          title: ar
            ? 'تذكير: رحلتك بعد ساعة'
            : 'Reminder: your trip is in an hour',
          body: ar
            ? `رحلتك إلى ${trip.toName} تنطلق خلال ساعة. كن في مكان التجمع في الموعد، وأكّد تواجدك عند وصولك.`
            : `Your trip to ${trip.toName} leaves within the hour. Be at the meeting point on time and confirm you're there when you arrive.`,
          data: { tripId, bookingId: booking.id },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Pre-trip reminder to passenger ${booking.userId} failed: ${err.message}`,
          ),
        );
    }

    const driverAr =
      (await this.notificationsService.getPreferredLocale(trip.driverId)) ===
      'ar';
    const riders = bookings.length;
    await this.notificationsService
      .create({
        userId: trip.driverId,
        type: 'presence_driver_prompt',
        title: driverAr
          ? 'تذكير: رحلتك بعد ساعة'
          : 'Reminder: your trip is in an hour',
        body: driverAr
          ? `رحلتك إلى ${trip.toName} تنطلق خلال ساعة (الركاب المؤكَّدون: ${riders}). فعّل الموقع وتوجّه إلى مكان التجمع.`
          : `Your trip to ${trip.toName} leaves within the hour with ${riders} passenger${riders === 1 ? '' : 's'}. Turn on location and head to the meeting point.`,
        data: { tripId },
      })
      .catch((err: Error) =>
        this.logger.warn(
          `Pre-trip reminder to driver ${trip.driverId} failed: ${err.message}`,
        ),
      );

    return true;
  }
}
