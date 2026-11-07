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

/** The second reminder, close to departure. */
export const SOON_REMINDER_LEAD_MS = 15 * 60 * 1000;

/**
 * The second reminder is skipped when the first went out this recently (a trip
 * created shortly before its time): two in a row would say the same thing.
 */
export const SOON_REMINDER_MIN_GAP_MS = 20 * 60 * 1000;

/**
 * The time left before departure, as the reminder says it: «بعد ساعة» only
 * when about an hour is left. A trip created five minutes ahead is reminded
 * at once, and must not be told it leaves in an hour.
 */
export function timeLeftPhrase(
  departure: Date | string | null | undefined,
  now: Date,
  ar: boolean,
): { title: string; body: string } {
  const minutes = departure
    ? Math.round((new Date(departure).getTime() - now.getTime()) / 60_000)
    : 60;
  if (minutes >= 55) {
    return ar
      ? { title: 'بعد ساعة', body: 'خلال ساعة' }
      : { title: 'in an hour', body: 'within the hour' };
  }
  if (minutes <= 1) {
    return ar ? { title: 'الآن', body: 'الآن' } : { title: 'now', body: 'now' };
  }
  if (!ar) {
    return { title: `in ${minutes} minutes`, body: `in ${minutes} minutes` };
  }
  const span =
    minutes === 2
      ? 'دقيقتين'
      : minutes <= 10
        ? `${minutes} دقائق`
        : `${minutes} دقيقة`;
  return { title: `بعد ${span}`, body: `خلال ${span}` };
}

/**
 * One-hour reminder for shared (scheduled) trips, to the driver and every
 * confirmed passenger. It doubles as the presence prompt: the passenger's
 * notification opens presence confirmation, the driver's the passenger roster.
 *
 * The `pre-trip-confirm` queue this used to hang off was never fed a job, so no
 * reminder had ever gone out. A minute sweep needs no per-trip scheduling and
 * survives trips whose departure time is edited. Passengers are reminded per
 * booking: it used to be once per trip, so anyone who booked after the
 * reminder went out (or on a trip created less than an hour ahead) never got
 * one.
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
      },
      select: ['id', 'departureTime'],
    });

    let sent = 0;
    for (const { id } of due) {
      if (await this.remind(id, now)) sent++;
    }
    const soonBefore = now.getTime() + SOON_REMINDER_LEAD_MS;
    for (const { id, departureTime } of due) {
      if (new Date(departureTime).getTime() > soonBefore) continue;
      if (await this.remindSoon(id, now)) sent++;
    }
    if (sent > 0)
      this.logger.log(`Sent pre-trip reminders for ${sent} trip(s)`);
    return sent;
  }

  /**
   * Sends what is still due for one trip: each confirmed passenger's reminder
   * once per booking, and the driver's once per trip. Returns whether anything
   * was sent.
   */
  async remind(tripId: string, now: Date = new Date()): Promise<boolean> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) return false;

    const bookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.CONFIRMED },
    });

    let sent = false;
    for (const booking of bookings) {
      // Claim first: only one instance (or one overlapping tick) sends.
      const claim = await this.bookingRepo.update(
        { id: booking.id, preTripReminderSentAt: IsNull() },
        { preTripReminderSentAt: new Date() },
      );
      if (!claim.affected) continue;
      sent = true;

      const ar =
        (await this.notificationsService.getPreferredLocale(booking.userId)) ===
        'ar';
      const left = timeLeftPhrase(trip.departureTime, now, ar);
      await this.notificationsService
        .create({
          userId: booking.userId,
          type: 'presence_prompt',
          title: ar
            ? `تذكير: رحلتك ${left.title}`
            : `Reminder: your trip is ${left.title}`,
          body: ar
            ? `رحلتك إلى ${trip.toName} تنطلق ${left.body}. كن في مكان التجمع في الموعد، وأكّد ركوبك عندما تصعد إلى السيارة.`
            : `Your trip to ${trip.toName} leaves ${left.body}. Be at the meeting point on time and confirm once you're in the car.`,
          data: { tripId, bookingId: booking.id },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Pre-trip reminder to passenger ${booking.userId} failed: ${err.message}`,
          ),
        );
    }

    const driverClaim = await this.tripRepo
      .createQueryBuilder()
      .update(TripEntity)
      .set({ preTripConfirmSentAt: () => 'NOW()' })
      .where('id = :tripId', { tripId })
      .andWhere('"preTripConfirmSentAt" IS NULL')
      .execute();
    if (!driverClaim.affected) return sent;

    const driverAr =
      (await this.notificationsService.getPreferredLocale(trip.driverId)) ===
      'ar';
    const riders = bookings.length;
    const driverLeft = timeLeftPhrase(trip.departureTime, now, driverAr);
    await this.notificationsService
      .create({
        userId: trip.driverId,
        type: 'presence_driver_prompt',
        title: driverAr
          ? `تذكير: رحلتك ${driverLeft.title}`
          : `Reminder: your trip is ${driverLeft.title}`,
        body: driverAr
          ? `رحلتك إلى ${trip.toName} تنطلق ${driverLeft.body} (الركاب المؤكَّدون: ${riders}). فعّل الموقع وتوجّه إلى مكان التجمع. تبدأ الرحلة عندما يؤكد الركاب ركوبهم.`
          : `Your trip to ${trip.toName} leaves ${driverLeft.body} with ${riders} passenger${riders === 1 ? '' : 's'}. Turn on location and head to the meeting point. The trip starts once passengers confirm they're on board.`,
        data: { tripId },
      })
      .catch((err: Error) =>
        this.logger.warn(
          `Pre-trip reminder to driver ${trip.driverId} failed: ${err.message}`,
        ),
      );

    return true;
  }

  /**
   * About 15 minutes before departure: the driver and every confirmed
   * passenger, once per trip. Returns whether it was sent.
   */
  async remindSoon(tripId: string, now: Date = new Date()): Promise<boolean> {
    const gapCutoff = new Date(now.getTime() - SOON_REMINDER_MIN_GAP_MS);
    const claim = await this.tripRepo
      .createQueryBuilder()
      .update(TripEntity)
      .set({ soonReminderSentAt: () => 'NOW()' })
      .where('id = :tripId', { tripId })
      .andWhere('"soonReminderSentAt" IS NULL')
      .andWhere('"preTripConfirmSentAt" < :gapCutoff', { gapCutoff })
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
      const left = timeLeftPhrase(trip.departureTime, now, ar);
      await this.notificationsService
        .create({
          userId: booking.userId,
          type: 'trip_reminder',
          title: ar
            ? `تذكير: رحلتك ${left.title}`
            : `Reminder: your trip is ${left.title}`,
          body: ar
            ? `رحلتك إلى ${trip.toName} تنطلق ${left.body}. توجّه إلى مكان التجمع، وأكّد ركوبك عندما تصعد إلى السيارة.`
            : `Your trip to ${trip.toName} leaves ${left.body}. Head to the meeting point and confirm once you're in the car.`,
          data: { tripId, bookingId: booking.id },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Soon reminder to passenger ${booking.userId} failed: ${err.message}`,
          ),
        );
    }

    const driverAr =
      (await this.notificationsService.getPreferredLocale(trip.driverId)) ===
      'ar';
    const driverLeft = timeLeftPhrase(trip.departureTime, now, driverAr);
    await this.notificationsService
      .create({
        userId: trip.driverId,
        type: 'presence_driver_prompt',
        title: driverAr
          ? `تذكير: رحلتك ${driverLeft.title}`
          : `Reminder: your trip is ${driverLeft.title}`,
        body: driverAr
          ? `رحلتك إلى ${trip.toName} تنطلق ${driverLeft.body}. كن في مكان التجمع، وعند صعود الركاب تبدأ الرحلة مع أول تأكيد أو اضغط «بدء الرحلة».`
          : `Your trip to ${trip.toName} leaves ${driverLeft.body}. Be at the meeting point; once passengers are in, it starts with the first confirmation or tap Start trip.`,
        data: { tripId },
      })
      .catch((err: Error) =>
        this.logger.warn(
          `Soon reminder to driver ${trip.driverId} failed: ${err.message}`,
        ),
      );
    return true;
  }
}
