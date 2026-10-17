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
  computeTripAutoCompleteDelayMs,
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

/**
 * When a shared trip starts. Not on the clock alone: a trip that leaves with
 * nobody confirmed on board isn't under way. So, at departure:
 * - a passenger already confirmed «أنا في السيارة» → it starts;
 * - nobody booked → it starts (nothing to wait for);
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
  ) {}

  /** Departure time came (the auto-start job, or the sweep re-checking). */
  async onDeparture(tripId: string): Promise<void> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      this.logger.warn(`trip-start: trip ${tripId} not found`);
      return;
    }
    if (trip.status === TripStatus.IN_PROGRESS) {
      // Already started (by a passenger, the driver, or an admin).
      await this.scheduleAutoComplete(trip);
      return;
    }
    if (!STARTABLE.includes(trip.status)) return;

    const bookings = await this.confirmedBookings(tripId);
    if (
      bookings.length === 0 ||
      bookings.some((b) => b.passengerPresenceConfirmedAt != null)
    ) {
      await this.start(trip.id, 'departure');
      return;
    }
    await this.askToBoard(trip, bookings);
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

  /** Departure, nobody on board: ask each passenger once, tell the driver. */
  private async askToBoard(trip: TripEntity, bookings: BookingEntity[]) {
    const claim = await this.tripRepo.update(
      { id: trip.id, boardingPromptSentAt: IsNull() },
      { boardingPromptSentAt: new Date() },
    );
    if (!claim.affected) return;

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
    const delay = computeTripAutoCompleteDelayMs(new Date(trip.departureTime));
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
