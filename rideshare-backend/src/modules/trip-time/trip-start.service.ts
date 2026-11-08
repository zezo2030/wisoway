import {
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { In, IsNull, Repository } from 'typeorm';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripStatus, TripType } from '../../database/entities/shared.enums';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { NotificationsService } from '../notifications/notifications.service';
import {
  DriverTripFeeService,
  TripFeeChargeResult,
} from '../driver-trip-fee/driver-trip-fee.service';
import {
  computeTripAutoEndDelayMs,
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
} from '../trips/trip-auto-start.util';

/** A trip in one of these has not started yet and may be started. */
const STARTABLE: TripStatus[] = [
  TripStatus.PUBLISHED,
  TripStatus.FULLY_BOOKED,
  TripStatus.ACTIVE,
];

/** The driver may start the trip themselves from this long before departure. */
export const DRIVER_START_LEAD_MS = 30 * 60 * 1000;

/** While a trip waits after departure, its reminders repeat this often… */
export const BOARDING_NUDGE_EVERY_MS = 5 * 60 * 1000;
/** …for this long. */
export const BOARDING_NUDGES_FOR_MS = 60 * 60 * 1000;

/**
 * When a shared trip starts. Not on the clock alone: a trip that leaves with
 * nobody confirmed on board isn't under way. So, at departure:
 * - a passenger already confirmed «أنا في السيارة» → it starts;
 * - no confirmed booking at all → it is cancelled: a shared trip with no
 *   passengers isn't a trip, and requests still unanswered are closed;
 * - otherwise it waits, and every passenger is asked «هل أنت في السيارة؟».
 * The first confirmation after departure starts it, and the driver can start
 * it themselves («بدء الرحلة») when the riders are in but didn't tap.
 */
@Injectable()
export class TripStartService {
  private readonly logger = new Logger(TripStartService.name);

  constructor(
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectQueue('trip-auto-complete')
    private readonly autoCompleteQueue: Queue,
    private readonly notifications: NotificationsService,
    private readonly driverTripFee: DriverTripFeeService,
    @InjectQueue('bookings-timeout')
    private readonly bookingsTimeoutQueue: Queue,
  ) {}

  /** Departure time came (the auto-start job, or the sweep re-checking). */
  async onDeparture(tripId: string, now = new Date()): Promise<void> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      this.logger.warn(`trip-start: trip ${tripId} not found`);
      return;
    }
    if (trip.status === TripStatus.IN_PROGRESS) {
      // Already started (by a passenger, the driver, or an admin).
      await this.expireUnanswered(trip.id);
      await this.scheduleAutoComplete(trip);
      return;
    }
    if (!STARTABLE.includes(trip.status)) return;

    const bookings = await this.confirmedBookings(tripId);
    if (bookings.length === 0) {
      await this.cancelEmpty(trip);
      return;
    }
    // The trip goes ahead with the passengers the driver accepted; requests
    // still unanswered at departure are cancelled.
    await this.expireUnanswered(trip.id);
    if (bookings.some((b) => b.passengerPresenceConfirmedAt != null)) {
      await this.start(trip.id, 'departure');
      return;
    }
    if (!(await this.askToBoard(trip, bookings))) {
      await this.nudgeToBoard(trip, bookings, now);
    }
  }

  /**
   * Requests the driver never answered, on a trip leaving without them. Each
   * has an expiry job (see BookingsTimeoutProcessor) that cancels it, frees
   * its seats and tells the passenger; departure just runs it now.
   */
  private async expireUnanswered(tripId: string): Promise<void> {
    const pending = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.PENDING },
      select: ['id'],
    });
    for (const { id } of pending) {
      const jobId = `booking-expire-${id}`;
      try {
        const job = await this.bookingsTimeoutQueue.getJob(jobId);
        if (job && (await job.isDelayed())) {
          await job.promote();
        } else if (!job) {
          await this.bookingsTimeoutQueue.add(
            'expire-booking',
            { bookingId: id },
            {
              jobId,
              attempts: 3,
              backoff: { type: 'exponential', delay: 5000 },
              removeOnComplete: true,
            },
          );
        }
      } catch (err) {
        this.logger.warn(
          `trip-start: expire request ${id} at departure: ${(err as Error).message}`,
        );
      }
    }
  }

  /**
   * Departure came with no confirmed passenger: the trip is called off, the
   * requests the driver never answered are closed, and everyone is told.
   */
  private async cancelEmpty(trip: TripEntity) {
    const claim = await this.tripRepo.update(
      { id: trip.id, status: In(STARTABLE) },
      { status: TripStatus.CANCELLED },
    );
    if (!claim.affected) return;

    const pending = await this.bookingRepo.find({
      where: { tripId: trip.id, status: BookingStatus.PENDING },
    });
    if (pending.length > 0) {
      await this.bookingRepo.update(
        { id: In(pending.map((b) => b.id)) },
        {
          status: BookingStatus.CANCELLED,
          cancellationReason: 'Trip departed with no confirmed passengers',
          cancelledAt: new Date(),
          cancelledBy: 'system',
        },
      );
    }
    for (const booking of pending) {
      const ar =
        (await this.notifications.getPreferredLocale(booking.userId)) === 'ar';
      this.notify(booking.userId, {
        type: 'trip_cancelled',
        title: ar ? 'تم إلغاء الرحلة' : 'Trip cancelled',
        body: ar
          ? `لم يقبل السائق طلبك قبل موعد الرحلة إلى ${trip.toName}، فأُلغيت الرحلة.`
          : `The driver didn't accept your request before the trip to ${trip.toName} was due, so it was cancelled.`,
        data: { tripId: trip.id, bookingId: booking.id },
      });
    }
    const driverAr =
      (await this.notifications.getPreferredLocale(trip.driverId)) === 'ar';
    this.notify(trip.driverId, {
      type: 'trip_cancelled',
      title: driverAr ? 'أُلغيت الرحلة' : 'Trip cancelled',
      body: driverAr
        ? `حان موعد رحلتك إلى ${trip.toName} ولا يوجد ركاب مؤكَّدون، فأُلغيت الرحلة.`
        : `Your trip to ${trip.toName} was due with no confirmed passengers, so it was cancelled.`,
      data: { tripId: trip.id },
    });
    this.logger.log(
      `trip-start: trip ${trip.id} cancelled at departure — no confirmed passengers (${pending.length} pending request(s) closed)`,
    );
  }

  /**
   * A passenger confirmed they're in the car. Before departure that only
   * marks them; from departure on it starts the trip.
   */
  async onPassengerBoarded(tripId: string, now = new Date()): Promise<void> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip || trip.tripType === TripType.INSTANT) return;
    if (!STARTABLE.includes(trip.status)) return;
    if (now.getTime() < new Date(trip.departureTime).getTime()) return;
    await this.start(trip.id, 'passenger');
  }

  /** «بدء الرحلة» on the driver's side. */
  async startByDriver(tripId: string, driverId: string, now = new Date()) {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException('هذه الرحلة ليست لك.');
    }
    if (trip.tripType === TripType.INSTANT) {
      throw new ConflictException('الرحلة المباشرة تبدأ من شاشة الرحلة.');
    }
    if (trip.status === TripStatus.IN_PROGRESS) return trip;
    if (!STARTABLE.includes(trip.status)) {
      throw new ConflictException({
        statusCode: 409,
        code: 'TRIP_NOT_STARTABLE',
        message: 'لا يمكن بدء هذه الرحلة.',
      });
    }
    const opensAt =
      new Date(trip.departureTime).getTime() - DRIVER_START_LEAD_MS;
    if (now.getTime() < opensAt) {
      throw new ConflictException({
        statusCode: 409,
        code: 'TRIP_START_TOO_EARLY',
        message: 'يمكنك بدء الرحلة قبل موعدها بـ 30 دقيقة كحد أقصى.',
      });
    }
    // A request still waiting for the driver's answer is not a passenger.
    if ((await this.confirmedBookings(tripId)).length === 0) {
      throw new ConflictException({
        statusCode: 409,
        code: 'TRIP_NO_PASSENGERS',
        message:
          'لا يوجد ركاب مؤكَّدون في هذه الرحلة. اقبل طلبات الحجز أولاً لتتمكن من بدء الرحلة.',
      });
    }
    await this.start(trip.id, 'driver');
    return this.tripRepo.findOne({ where: { id: tripId } });
  }

  /**
   * Moves the trip and its confirmed bookings in progress, charges the
   * driver's trip fee and tells everyone. Idempotent: only the call that
   * flips the status does the rest. Returns whether this call started it.
   */
  async start(
    tripId: string,
    by: 'departure' | 'passenger' | 'driver',
  ): Promise<boolean> {
    const now = new Date();
    const claim = await this.tripRepo.update(
      { id: tripId, status: In(STARTABLE) },
      { status: TripStatus.IN_PROGRESS, tripStartedAt: now },
    );
    if (!claim.affected) return false;
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) return false;

    const bookings = await this.confirmedBookings(tripId);
    if (bookings.length > 0) {
      await this.bookingRepo.update(
        { id: In(bookings.map((b) => b.id)) },
        { status: BookingStatus.IN_PROGRESS },
      );
    }
    this.logger.log(
      `trip-start: trip ${tripId} started by ${by} at ${now.toISOString()}`,
    );

    // The one debit for this trip. A failure here must not stop the trip: the
    // reconciliation sweep re-runs any trip left with driverWalletChargeApplied
    // still false.
    let feeCharge: TripFeeChargeResult | undefined;
    try {
      feeCharge = await this.driverTripFee.chargeAtTripStart(trip);
    } catch (err) {
      this.logger.error(
        `trip-start: fee charge failed for trip ${tripId}: ${(err as Error).message}`,
      );
    }

    this.notify(trip.driverId, {
      type: 'trip_started',
      title: 'بدأت الرحلة',
      body: `بدأت رحلتك إلى ${trip.toName}.`,
      data: { tripId },
    });
    for (const booking of bookings) {
      // Whoever hasn't said they're in the car is asked now.
      this.notify(
        booking.userId,
        booking.passengerPresenceConfirmedAt
          ? {
              type: 'trip_started',
              title: 'بدأت الرحلة',
              body: `بدأت رحلتك إلى ${trip.toName}. يمكنك مشاركة تتبع الرحلة المباشر مع أحد.`,
              data: { tripId },
            }
          : {
              type: 'presence_prompt',
              title: 'بدأت الرحلة — هل أنت في السيارة؟',
              body: 'أكّد ركوبك ليعرف السائق أنك معه.',
              data: { tripId, bookingId: booking.id },
            },
      );
    }
    if (feeCharge && feeCharge.charged > 0) {
      this.notify(trip.driverId, {
        type: 'trip_fee_charged',
        title: 'رسوم الرحلة',
        body: `تم خصم ${feeCharge.charged.toFixed(2)} ${feeCharge.currency} من محفظتك كرسوم هذه الرحلة.`,
        data: { tripId },
      });
    }

    await this.scheduleAutoComplete(trip);
    return true;
  }

  /**
   * Departure, nobody on board: ask each passenger, tell the driver. Returns
   * whether this call sent it (it goes out once per trip).
   */
  private async askToBoard(
    trip: TripEntity,
    bookings: BookingEntity[],
  ): Promise<boolean> {
    const claim = await this.tripRepo.update(
      { id: trip.id, boardingPromptSentAt: IsNull() },
      { boardingPromptSentAt: new Date() },
    );
    if (!claim.affected) return false;

    for (const booking of bookings) {
      const ar =
        (await this.notifications.getPreferredLocale(booking.userId)) === 'ar';
      this.notify(booking.userId, {
        type: 'presence_prompt',
        title: ar
          ? 'حان موعد رحلتك — هل أنت في السيارة؟'
          : 'Time to go — are you in the car?',
        body: ar
          ? `رحلتك إلى ${trip.toName} تبدأ عندما تؤكد ركوبك.`
          : `Your trip to ${trip.toName} starts once you confirm you're on board.`,
        data: { tripId: trip.id, bookingId: booking.id },
      });
    }
    const driverAr =
      (await this.notifications.getPreferredLocale(trip.driverId)) === 'ar';
    this.notify(trip.driverId, {
      type: 'trip_awaiting_boarding',
      title: driverAr ? 'بانتظار تأكيد الركاب' : 'Waiting for passengers',
      body: driverAr
        ? 'طلبنا من الركاب تأكيد ركوبهم. تبدأ الرحلة مع أول تأكيد، أو اضغط «بدء الرحلة» إذا كانوا معك.'
        : "We asked your passengers to confirm they're on board. The trip starts with the first confirmation, or tap Start trip if they're with you.",
      data: { tripId: trip.id },
    });
    this.logger.log(
      `trip-start: trip ${trip.id} waiting for boarding (${bookings.length} booking(s))`,
    );
    return true;
  }

  /**
   * The trip is still waiting after departure: remind the driver to start it
   * and whoever hasn't confirmed to do so, every few minutes for the first
   * hour. The lifecycle sweep re-runs onDeparture every 5 minutes, which is
   * what drives this.
   */
  private async nudgeToBoard(
    trip: TripEntity,
    bookings: BookingEntity[],
    now: Date,
  ): Promise<void> {
    const lateMs = now.getTime() - new Date(trip.departureTime).getTime();
    if (lateMs < 0 || lateMs > BOARDING_NUDGES_FOR_MS) return;

    // A little under the interval, so a sweep tick a few seconds early still counts.
    const cutoff = new Date(now.getTime() - BOARDING_NUDGE_EVERY_MS + 30_000);
    const claim = await this.tripRepo
      .createQueryBuilder()
      .update(TripEntity)
      .set({ boardingReminderSentAt: now })
      .where('id = :id', { id: trip.id })
      .andWhere('"boardingPromptSentAt" < :cutoff', { cutoff })
      .andWhere(
        '("boardingReminderSentAt" IS NULL OR "boardingReminderSentAt" < :cutoff)',
        { cutoff },
      )
      .execute();
    if (!claim.affected) return;

    const minutes = Math.max(1, Math.round(lateMs / 60_000));
    const driverAr =
      (await this.notifications.getPreferredLocale(trip.driverId)) === 'ar';
    this.notify(trip.driverId, {
      type: 'trip_awaiting_boarding',
      title: driverAr ? 'تذكير: ابدأ الرحلة' : 'Reminder: start your trip',
      body: driverAr
        ? `حان موعد رحلتك إلى ${trip.toName} منذ ${minutes} دقيقة. إذا صعد الركاب اضغط «بدء الرحلة»، وتبدأ تلقائيًا عند أول تأكيد من راكب.`
        : `Your trip to ${trip.toName} was due ${minutes} min ago. If your passengers are in, tap Start trip; it also starts once a passenger confirms.`,
      data: { tripId: trip.id },
    });

    for (const booking of bookings) {
      if (booking.passengerPresenceConfirmedAt != null) continue;
      const ar =
        (await this.notifications.getPreferredLocale(booking.userId)) === 'ar';
      this.notify(booking.userId, {
        type: 'presence_prompt',
        title: ar ? 'هل أنت في السيارة؟' : 'Are you in the car?',
        body: ar
          ? `رحلتك إلى ${trip.toName} تبدأ عندما تؤكد ركوبك. أكّد الآن إذا صعدت.`
          : `Your trip to ${trip.toName} starts once you confirm you're on board. Confirm now if you're in.`,
        data: { tripId: trip.id, bookingId: booking.id },
      });
    }
    this.logger.log(
      `trip-start: trip ${trip.id} still waiting ${minutes} min after departure, reminders sent`,
    );
  }

  private confirmedBookings(tripId: string) {
    return this.bookingRepo.find({
      where: { tripId, status: BookingStatus.CONFIRMED },
    });
  }

  private notify(
    userId: string,
    n: {
      type: string;
      title: string;
      body: string;
      data: Record<string, unknown>;
    },
  ) {
    this.notifications
      .create({ userId, ...n })
      .catch((err: Error) =>
        this.logger.warn(`${n.type} notify ${userId}: ${err.message}`),
      );
  }

  private async scheduleAutoComplete(trip: TripEntity): Promise<void> {
    const delay = computeTripAutoEndDelayMs(trip);
    try {
      await this.autoCompleteQueue.add(
        'enforce',
        { tripId: trip.id },
        {
          delay,
          jobId: `${TRIP_AUTO_COMPLETE_JOB_ID_PREFIX}${trip.id}`,
          removeOnComplete: true,
          attempts: 2,
          backoff: { type: 'exponential', delay: 30000 },
        },
      );
    } catch (err) {
      this.logger.warn(
        `Failed to schedule auto-complete for trip ${trip.id}: ${(err as Error).message}`,
      );
    }
  }
}
