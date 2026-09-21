import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import {
  BookingEntity,
  BookingStatus,
} from '../../database/entities/booking.entity';

/** How many passenger photos a trip card shows before the "+N" counter. */
const MAX_AVATARS = 3;

/** Statuses that mean the seats are actually taken on the trip. */
const LIVE_STATUSES = [BookingStatus.CONFIRMED, BookingStatus.IN_PROGRESS];

export interface TripPassengerSummary {
  /** Seats taken by live bookings — drives the "N seats left" line. */
  bookedSeats: number;
  /**
   * Photos of the passengers already on board, oldest booking first. Only
   * photos are exposed here: no names, no phone numbers.
   */
  passengerAvatars: string[];
}

/**
 * Aggregates "who is already on this trip" for trip list cards, in a single
 * query for a whole page of trips.
 */
@Injectable()
export class TripPassengerSummaryService {
  constructor(
    @InjectRepository(BookingEntity)
    private bookingRepo: Repository<BookingEntity>,
  ) {}

  async forTrips(tripIds: string[]): Promise<Map<string, TripPassengerSummary>> {
    const summaries = new Map<string, TripPassengerSummary>();
    if (tripIds.length === 0) return summaries;

    const bookings = await this.bookingRepo.find({
      where: { tripId: In(tripIds), status: In(LIVE_STATUSES) },
      relations: ['user'],
      order: { createdAt: 'ASC' },
    });

    for (const booking of bookings) {
      const summary = summaries.get(booking.tripId) ?? {
        bookedSeats: 0,
        passengerAvatars: [],
      };
      summary.bookedSeats += booking.seatCount ?? 0;

      const photoUrl = booking.user?.photoUrl;
      if (photoUrl && summary.passengerAvatars.length < MAX_AVATARS) {
        summary.passengerAvatars.push(photoUrl);
      }

      summaries.set(booking.tripId, summary);
    }

    return summaries;
  }
}
