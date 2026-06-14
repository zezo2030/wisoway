import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Not } from 'typeorm';
import { BookingEntity, BookingStatus } from '../../database/entities/booking.entity';
import { TripEntity } from '../../database/entities/trip.entity';
import { UserEntity } from '../../database/entities/user.entity';
import {
  PendingChargeEntity,
  PendingChargeKind,
} from '../../database/entities/pending-charge.entity';

export interface ListNoShowReportsQuery {
  page?: number;
  limit?: number;
  /** When true, only include trips where majority of confirmed passengers reported absence. */
  majorityOnly?: boolean;
  /** Filter: only trips with no fine issued yet. */
  unfinedOnly?: boolean;
}

export interface ReportRow {
  tripId: string;
  driverId: string;
  driverName: string | null;
  driverPhone: string | null;
  fromName: string;
  toName: string;
  departureTime: string;
  tripStatus: string;
  confirmedPassengers: number;
  reportedAbsenceCount: number;
  confirmedPresenceCount: number;
  majorityReached: boolean;
  earliestReportAt: string | null;
  latestReportAt: string | null;
  reporterBookingIds: string[];
  fineIssued: boolean;
  fineId: string | null;
}

@Injectable()
export class AdminNoShowService {
  constructor(
    @InjectRepository(BookingEntity)
    private readonly bookingRepo: Repository<BookingEntity>,
    @InjectRepository(TripEntity)
    private readonly tripRepo: Repository<TripEntity>,
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(PendingChargeEntity)
    private readonly chargeRepo: Repository<PendingChargeEntity>,
  ) {}

  /**
   * Aggregates passenger-reported driver absences into one row per trip.
   * Used by admins to decide whether to issue a manual driver fine.
   */
  async list(query: ListNoShowReportsQuery): Promise<{
    data: ReportRow[];
    meta: { page: number; limit: number; total: number; totalPages: number };
  }> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(100, Math.max(1, query.limit ?? 20));

    const tripsWithReports = await this.bookingRepo
      .createQueryBuilder('b')
      .select('b.tripId', 'tripId')
      .addSelect('MIN(b.passengerReportedDriverAbsentAt)', 'firstReportAt')
      .where('b.passengerReportedDriverAbsentAt IS NOT NULL')
      .groupBy('b.tripId')
      .orderBy('MIN(b.passengerReportedDriverAbsentAt)', 'DESC')
      .getRawMany<{ tripId: string; firstReportAt: Date }>();

    const total = tripsWithReports.length;
    const slice = tripsWithReports.slice((page - 1) * limit, page * limit);
    if (slice.length === 0) {
      return { data: [], meta: { page, limit, total, totalPages: 0 } };
    }

    const tripIds = slice.map((r) => r.tripId);
    const trips = await this.tripRepo.find({ where: tripIds.map((id) => ({ id })) });
    const tripMap = new Map(trips.map((t) => [t.id, t]));

    const allBookings = await this.bookingRepo.find({
      where: tripIds.map((id) => ({ tripId: id })),
    });

    const driverIds = Array.from(new Set(trips.map((t) => t.driverId)));
    const drivers = await this.userRepo.find({
      where: driverIds.map((id) => ({ id })),
    });
    const driverMap = new Map(drivers.map((d) => [d.id, d]));

    const fines = await this.chargeRepo.find({
      where: tripIds.map((id) => ({
        tripId: id,
        kind: PendingChargeKind.DRIVER_NO_SHOW,
      })),
    });
    const fineByTrip = new Map(fines.map((f) => [f.tripId, f]));

    const rows: ReportRow[] = slice
      .map((entry) => {
        const trip = tripMap.get(entry.tripId);
        if (!trip) return null;
        const driver = driverMap.get(trip.driverId);
        const tripBookings = allBookings.filter((b) => b.tripId === entry.tripId);
        const reporters = tripBookings.filter(
          (b) => b.passengerReportedDriverAbsentAt != null,
        );
        const presence = tripBookings.filter(
          (b) => b.passengerPresenceConfirmedAt != null,
        );
        const confirmedCount = tripBookings.filter(
          (b) =>
            b.status === BookingStatus.CONFIRMED ||
            b.status === BookingStatus.IN_PROGRESS ||
            b.status === BookingStatus.COMPLETED ||
            b.status === BookingStatus.NO_SHOW,
        ).length;
        const majority =
          reporters.length > 0 && reporters.length * 2 > confirmedCount;
        const fine = fineByTrip.get(entry.tripId) ?? null;

        const reportTimes = reporters
          .map((b) => b.passengerReportedDriverAbsentAt as Date)
          .filter(Boolean)
          .map((d) => new Date(d).getTime());
        const earliest = reportTimes.length ? new Date(Math.min(...reportTimes)) : null;
        const latest = reportTimes.length ? new Date(Math.max(...reportTimes)) : null;

        return {
          tripId: trip.id,
          driverId: trip.driverId,
          driverName: driver?.name ?? null,
          driverPhone: driver?.phoneNumber ?? null,
          fromName: trip.fromName,
          toName: trip.toName,
          departureTime: new Date(trip.departureTime).toISOString(),
          tripStatus: trip.status,
          confirmedPassengers: confirmedCount,
          reportedAbsenceCount: reporters.length,
          confirmedPresenceCount: presence.length,
          majorityReached: majority,
          earliestReportAt: earliest ? earliest.toISOString() : null,
          latestReportAt: latest ? latest.toISOString() : null,
          reporterBookingIds: reporters.map((b) => b.id),
          fineIssued: !!fine,
          fineId: fine?.id ?? null,
        } as ReportRow;
      })
      .filter((r): r is ReportRow => r !== null)
      .filter((r) => (query.majorityOnly ? r.majorityReached : true))
      .filter((r) => (query.unfinedOnly ? !r.fineIssued : true));

    return {
      data: rows,
      meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
    };
  }

  async detail(tripId: string): Promise<{
    summary: ReportRow;
    bookings: Array<{
      bookingId: string;
      passengerId: string;
      passengerName: string | null;
      passengerPhone: string | null;
      status: string;
      reportedAbsentAt: string | null;
      confirmedPresenceAt: string | null;
    }>;
  }> {
    const list = await this.list({ page: 1, limit: 1 });
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    // Reuse list() aggregation to build the summary for this one trip
    const all = await this.list({ page: 1, limit: 9999 });
    const summary = all.data.find((r) => r.tripId === tripId);
    if (!summary) {
      throw new NotFoundException('No reports found for this trip');
    }

    const bookings = await this.bookingRepo.find({
      where: { tripId },
      relations: ['user'],
    });

    return {
      summary,
      bookings: bookings.map((b) => ({
        bookingId: b.id,
        passengerId: b.userId,
        passengerName: b.user?.name ?? null,
        passengerPhone: b.user?.phoneNumber ?? null,
        status: b.status,
        reportedAbsentAt: b.passengerReportedDriverAbsentAt
          ? new Date(b.passengerReportedDriverAbsentAt).toISOString()
          : null,
        confirmedPresenceAt: b.passengerPresenceConfirmedAt
          ? new Date(b.passengerPresenceConfirmedAt).toISOString()
          : null,
      })),
    };
  }
}
