import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
  Optional,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import {
  TripStatus,
  TripType,
  PgUserRole,
} from '../../database/entities/shared.enums';
import { UserEntity } from '../../database/entities/user.entity';
import { PassengerConfirmDto } from './dto/passenger-confirm.dto';
import { DriverConfirmDto } from './dto/driver-confirm.dto';
import { CompleteTripDto } from './dto/complete-trip.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { PresenceService } from './presence.service';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { ErrorCodes } from '../../common/errors/error-codes';
import {
  TRIP_AUTO_START_JOB_ID_PREFIX,
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
} from '../trips/trip-auto-start.util';
import { AdminAlertsService } from '../admin/admin-alerts.service';
import { TripEmergencyDto } from './dto/trip-emergency.dto';
import { DriverTripFeeService } from '../driver-trip-fee/driver-trip-fee.service';
import { RidePaymentsService } from '../ride-payments/ride-payments.service';
import { InstantMeterService } from '../instant-rides/instant-meter.service';

@Injectable()
export class TripTimeService {
  private readonly logger = new Logger(TripTimeService.name);

  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
    @InjectRepository(BookingSeatEntity)
    private bookingSeatRepo: Repository<BookingSeatEntity>,
    @InjectRepository(TripEntity)
    private tripRepo: Repository<TripEntity>,
    @InjectRepository(TripShareLinkEntity)
    private shareLinkRepo: Repository<TripShareLinkEntity>,
    private notificationsService: NotificationsService,
    private readonly presenceService: PresenceService,
    private readonly adminAlertsService: AdminAlertsService,
    @InjectQueue('trip-auto-start')
    private readonly tripAutoStartQueue: Queue,
    @InjectQueue('trip-auto-complete')
    private readonly tripAutoCompleteQueue: Queue,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    private readonly driverTripFee: DriverTripFeeService,
    private readonly ridePayments: RidePaymentsService,
    @Optional() private readonly meter?: InstantMeterService,
  ) {}

  async passengerConfirm(
    bookingId: string,
    userId: string,
    dto: PassengerConfirmDto,
  ) {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip'],
    });
    if (!booking) throw new NotFoundException('Booking not found');
    if (booking.userId !== userId) {
      throw new ForbiddenException('You can only confirm your own booking');
    }
    if (
      booking.status !== BookingStatus.CONFIRMED &&
      booking.status !== BookingStatus.IN_PROGRESS
    ) {
      throw new BadRequestException(
        'Booking must be confirmed or in progress to confirm presence',
      );
    }

    const trip = booking.trip;
    const departureTime = new Date(trip.departureTime);
    const now = new Date();
    const windowStart = new Date(departureTime.getTime() - 60 * 60 * 1000);
    const windowEnd = new Date(departureTime.getTime() + 30 * 60 * 1000);

    if (now < windowStart || now > windowEnd) {
      throw new BadRequestException({
        code: ErrorCodes.TIMING_WINDOW,
        message:
          'Passenger confirmation is only available within 60 minutes before to 30 minutes after departure',
      });
    }

    if (dto.driverPresent) {
      booking.passengerPresenceConfirmedAt = now;
    } else {
      booking.passengerReportedDriverAbsentAt = now;
    }

    const saved = await this.bookingRepo.save(booking);

    if (!dto.driverPresent) {
      this.notificationsService
        .create({
          userId: trip.driverId,
          type: 'passenger_reported_driver_absent',
          title: 'Passenger Reported Absence',
          body: `A passenger reported you are not at the meeting point for trip to ${trip.toName}`,
          data: { tripId: trip.id, bookingId },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Failed to notify driver of absence report: ${err.message}`,
          ),
        );

      void this.notifyAdminsOnAbsenceReport(trip, bookingId);
    }

    return saved;
  }

  /**
   * Surfaces a passenger no-show report to all admins. Fines remain manual —
   * admins decide whether to charge via POST /admin/fines after reviewing.
   */
  private async notifyAdminsOnAbsenceReport(
    trip: TripEntity,
    bookingId: string,
  ): Promise<void> {
    try {
      const admins = await this.bookingRepo.manager
        .getRepository(UserEntity)
        .find({ where: { role: PgUserRole.ADMIN } });

      const absentCount = await this.bookingRepo.count({
        where: { tripId: trip.id },
      });

      for (const admin of admins) {
        await this.notificationsService
          .create({
            userId: admin.id,
            type: 'admin_no_show_report',
            title: 'بلاغ غياب سائق',
            body: `راكب بلّغ أن السائق لم يحضر للرحلة إلى ${trip.toName}.`,
            data: {
              tripId: trip.id,
              bookingId,
              driverId: trip.driverId,
              reportedAt: new Date().toISOString(),
              bookingsOnTrip: absentCount,
            },
          })
          .catch((err: Error) =>
            this.logger.warn(`admin no-show notify: ${err.message}`),
          );
      }
    } catch (err) {
      this.logger.warn(
        `notifyAdminsOnAbsenceReport: ${(err as Error).message}`,
      );
    }
  }

  async driverConfirm(
    bookingId: string,
    driverId: string,
    dto: DriverConfirmDto,
  ) {
    const booking = await this.bookingRepo.findOne({
      where: { id: bookingId },
      relations: ['trip', 'seats'],
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const trip = booking.trip;
    if (trip.driverId !== driverId) {
      throw new ForbiddenException(
        'Only the trip driver can confirm passenger presence',
      );
    }
    if (
      booking.status !== BookingStatus.CONFIRMED &&
      booking.status !== BookingStatus.IN_PROGRESS
    ) {
      throw new BadRequestException('Booking must be confirmed or in progress');
    }

    const seat = (booking.seats || []).find(
      (s) => s.seatNumber === dto.seatNumber,
    );
    if (!seat) {
      throw new BadRequestException(
        `Seat ${dto.seatNumber} not found in this booking`,
      );
    }

    const now = new Date();
    if (dto.present) {
      seat.presenceConfirmedAt = now;
      booking.driverConfirmedPassengerAt = now;
    } else {
      seat.markedAbsentAt = now;
    }
    await this.bookingSeatRepo.save(seat);

    const allSeats = (booking.seats || []).filter((s) => s.id !== seat.id);
    allSeats.push(seat);

    const allAbsent = allSeats.every((s) => s.markedAbsentAt != null);
    if (allAbsent) {
      booking.driverMarkedAbsentAt = now;
    }

    const saved = await this.bookingRepo.save(booking);
    return saved;
  }

  /**
   * Driver presses "تم الوصول للوجهة" (arrived). The trip must already be
   * IN_PROGRESS (set automatically at departureTime by TripAutoStartProcessor).
   */
  async completeTrip(
    tripId: string,
    driverId: string,
    dto: CompleteTripDto,
  ): Promise<TripEntity> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.driverId !== driverId) {
      throw new ForbiddenException({
        message: 'Only the trip driver can complete the trip',
        code: ErrorCodes.NOT_TRIP_DRIVER,
      });
    }
    if (trip.status !== TripStatus.IN_PROGRESS) {
      throw new BadRequestException(
        'Trip must be in progress to mark as arrived',
      );
    }
    // An instant ride reaches its destination only after the passenger got in.
    if (trip.tripType === TripType.INSTANT && !trip.tripStartedAt) {
      throw new BadRequestException('ابدأ الرحلة أولاً قبل إنهائها.');
    }

    const now = new Date();
    // An instant ride is metered: the fare is set now from the distance
    // driven, the time and the wait — before the payment asks for it.
    if (trip.tripType === TripType.INSTANT && this.meter) {
      await this.meter
        .settle(trip, now)
        .catch((err: Error) =>
          this.logger.error(`Metering trip ${tripId} failed: ${err.message}`),
        );
    }
    trip.status = TripStatus.COMPLETED;
    trip.tripCompletedAt = now;
    const savedTrip = await this.tripRepo.save(trip);

    const noShowMap = new Map<string, Set<string>>();
    if (dto.noShowSeats?.length) {
      for (const entry of dto.noShowSeats) {
        if (!noShowMap.has(entry.bookingId)) {
          noShowMap.set(entry.bookingId, new Set());
        }
        noShowMap.get(entry.bookingId)!.add(entry.seatNumber);
      }

      for (const [bookingId, absentSeatNumbers] of noShowMap.entries()) {
        const bookingSeats = await this.bookingSeatRepo.find({
          where: { bookingId },
        });
        for (const seat of bookingSeats) {
          if (absentSeatNumbers.has(seat.seatNumber)) {
            seat.markedAbsentAt = now;
            await this.bookingSeatRepo.save(seat);
          }
        }

        const allAbsent = bookingSeats.every((s) =>
          absentSeatNumbers.has(s.seatNumber),
        );
        if (allAbsent) {
          const booking = await this.bookingRepo.findOne({
            where: { id: bookingId },
          });
          if (booking) {
            booking.status = BookingStatus.NO_SHOW;
            booking.driverMarkedAbsentAt = now;
            await this.bookingRepo.save(booking);
          }
        }
      }
    }

    // An instant ride's one booking is never moved to IN_PROGRESS — it goes
    // straight from CONFIRMED to COMPLETED here.
    const isInstant = trip.tripType === TripType.INSTANT;
    const activeBookings = await this.bookingRepo.find({
      where: {
        tripId,
        status: isInstant
          ? In([BookingStatus.IN_PROGRESS, BookingStatus.CONFIRMED])
          : BookingStatus.IN_PROGRESS,
      },
      relations: ['seats'],
    });
    // On a shared trip only those who rode are done — and asked for a fare:
    // the passenger confirmed «أنا في السيارة», or the driver vouched for
    // them. Nobody else is charged; their booking ends as a no-show.
    const notBoarded: BookingEntity[] = [];
    for (const booking of activeBookings) {
      const rode = isInstant || hasBoarded(booking);
      booking.status = rode ? BookingStatus.COMPLETED : BookingStatus.NO_SHOW;
      if (!rode) notBoarded.push(booking);
      await this.bookingRepo.save(booking);
    }

    // Fares: cash passengers are asked to pay the driver, CliQ passengers get
    // a request-to-pay. Never blocks completion.
    await this.ridePayments
      .openForTrip(tripId)
      .catch((err: Error) =>
        this.logger.error(`Opening fare payments failed: ${err.message}`),
      );

    // Presence summarizes the commission posted by openForTrip above.
    const settlement = await this.presenceService.settleTripPresence(tripId);

    // Driver no-show is tracked via passengerReportedDriverAbsentAt for admin
    // review. Fines are no longer auto-applied; admin creates them manually via
    // POST /admin/fines after investigating.

    // Those who rode are invited to rate; those who never confirmed boarding
    // hear why nothing is asked of them.
    const notBoardedIds = new Set(notBoarded.map((b) => b.id));
    const allBookings = await this.bookingRepo.find({
      where: {
        tripId,
        status: In([BookingStatus.COMPLETED, BookingStatus.NO_SHOW]),
      },
    });
    for (const booking of allBookings) {
      const ar =
        (await this.notificationsService.getPreferredLocale(booking.userId)) ===
        'ar';
      const skipped = notBoardedIds.has(booking.id);
      if (!skipped && booking.status !== BookingStatus.COMPLETED) continue;
      await this.notificationsService
        .create({
          userId: booking.userId,
          type: 'trip_completed',
          title: ar ? 'انتهت الرحلة' : 'Trip completed',
          body: skipped
            ? ar
              ? `انتهت الرحلة إلى ${trip.toName}. لم تؤكد ركوبك فيها، فلم تُطلب منك أجرة.`
              : `The trip to ${trip.toName} has ended. You didn't confirm you were on board, so no fare is due.`
            : ar
              ? `انتهت رحلتك إلى ${trip.toName}. يمكنك الآن تقييم الرحلة.`
              : `The trip to ${trip.toName} has been completed`,
          data: { tripId, toName: trip.toName },
        })
        .catch((err: Error) =>
          this.logger.warn(
            `Failed to notify passenger of completion: ${err.message}`,
          ),
        );
    }

    await this.shareLinkRepo
      .createQueryBuilder()
      .update(TripShareLinkEntity)
      .set({ expiresAt: new Date(now.getTime() + 30 * 60 * 1000) })
      .where('tripId = :tripId', { tripId })
      .execute();

    this.logger.log(
      `Trip ${tripId} marked arrived by driver ${driverId} — ` +
        `${settlement.billableSeats}/${settlement.bookedSeats} seats billable, ` +
        `captured ${settlement.captured} ${settlement.currency}`,
    );
    await this.cancelTripLifecycleJobs(tripId);

    // Re-read so the response carries the settlement columns written above.
    const finalTrip =
      (await this.tripRepo.findOne({ where: { id: tripId } })) ?? savedTrip;
    return Object.assign(finalTrip, { settlement });
  }

  private async cancelTripLifecycleJobs(tripId: string): Promise<void> {
    try {
      const startJob = await this.tripAutoStartQueue.getJob(
        `${TRIP_AUTO_START_JOB_ID_PREFIX}${tripId}`,
      );
      await startJob?.remove();
    } catch (err) {
      this.logger.warn(
        `cancel trip-auto-start ${tripId}: ${(err as Error).message}`,
      );
    }
    try {
      const completeJob = await this.tripAutoCompleteQueue.getJob(
        `${TRIP_AUTO_COMPLETE_JOB_ID_PREFIX}${tripId}`,
      );
      await completeJob?.remove();
    } catch (err) {
      this.logger.warn(
        `cancel trip-auto-complete ${tripId}: ${(err as Error).message}`,
      );
    }
  }

  async reportEmergency(tripId: string, userId: string, dto: TripEmergencyDto) {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) {
      throw new NotFoundException('Trip not found');
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
      const inProgressBooking = await this.bookingRepo.findOne({
        where: {
          tripId,
          userId,
          status: BookingStatus.IN_PROGRESS,
        },
      });
      isConfirmedPassenger = !!booking || !!inProgressBooking;
    }

    if (!isDriver && !isConfirmedPassenger) {
      throw new ForbiddenException(
        'Only the driver or a confirmed passenger can trigger emergency',
      );
    }

    if (
      trip.status !== TripStatus.IN_PROGRESS &&
      trip.status !== TripStatus.PUBLISHED
    ) {
      throw new BadRequestException(
        'Emergency is only available for active trips',
      );
    }

    const reporter = await this.userRepo.findOne({
      where: { id: userId },
      select: ['id', 'name'],
    });

    const latitude = dto.latitude ?? trip.lastDriverLocationLat ?? null;
    const longitude = dto.longitude ?? trip.lastDriverLocationLng ?? null;

    await this.adminAlertsService.notifyTripEmergency({
      tripId: trip.id,
      reporterUserId: userId,
      reporterName: reporter?.name?.trim() || 'User',
      fromName: trip.fromName,
      toName: trip.toName,
      latitude,
      longitude,
    });

    this.logger.warn(
      JSON.stringify({
        event: 'trip.emergency',
        tripId,
        userId,
        latitude,
        longitude,
      }),
    );

    return {
      ok: true,
      tripId,
      notifiedAt: new Date().toISOString(),
    };
  }
}

/**
 * Whether the passenger of a shared-trip booking rode: they confirmed
 * «أنا في السيارة» (for the booking or any of its seats), or the driver
 * vouched for one of its seats. Only such bookings are asked for a fare.
 */
export function hasBoarded(booking: BookingEntity): boolean {
  if (booking.passengerPresenceConfirmedAt) return true;
  return (booking.seats ?? []).some(
    (s) => s.passengerSelfConfirmedAt != null || s.presenceConfirmedAt != null,
  );
}
