import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bull';
import type { Queue } from 'bull';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';
import { BookingSeatEntity } from '../../database/entities/booking-seat.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { TripStatus, PgUserRole } from '../../database/entities/shared.enums';
import { UserEntity } from '../../database/entities/user.entity';
import { PassengerConfirmDto } from './dto/passenger-confirm.dto';
import { DriverConfirmDto } from './dto/driver-confirm.dto';
import { CompleteTripDto } from './dto/complete-trip.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { TripShareLinkEntity } from '../../database/entities/trip-share-link.entity';
import { ErrorCodes } from '../../common/errors/error-codes';
import {
  TRIP_AUTO_START_JOB_ID_PREFIX,
  TRIP_AUTO_COMPLETE_JOB_ID_PREFIX,
} from '../trips/trip-auto-start.util';

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
    @InjectQueue('trip-auto-start')
    private readonly tripAutoStartQueue: Queue,
    @InjectQueue('trip-auto-complete')
    private readonly tripAutoCompleteQueue: Queue,
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

    const now = new Date();
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

    const activeBookings = await this.bookingRepo.find({
      where: { tripId, status: BookingStatus.IN_PROGRESS },
    });
    for (const booking of activeBookings) {
      booking.status = BookingStatus.COMPLETED;
      await this.bookingRepo.save(booking);
    }

    // Driver no-show is tracked via passengerReportedDriverAbsentAt for admin
    // review. Fines are no longer auto-applied; admin creates them manually via
    // POST /admin/fines after investigating.

    const allBookings = await this.bookingRepo.find({
      where: { tripId },
    });
    for (const booking of allBookings) {
      await this.notificationsService
        .create({
          userId: booking.userId,
          type: 'trip_completed',
          title: 'Trip Completed',
          body: `The trip to ${trip.toName} has been completed`,
          data: { tripId },
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

    this.logger.log(`Trip ${tripId} marked arrived by driver ${driverId}`);
    await this.cancelTripLifecycleJobs(tripId);
    return savedTrip;
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
}
