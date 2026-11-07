import type { BookingEntity } from '../../database/entities/booking.entity';
import { seatCountsForCommission } from '../../database/entities/booking-seat.entity';

type RiddenBooking = Pick<
  BookingEntity,
  'seats' | 'seatCount' | 'passengerPresenceConfirmedAt' | 'locationVerifiedAt'
>;

/**
 * How many of a shared booking's seats rode, out of how many were booked. The
 * one rule for both sides of the money: the driver's commission and what the
 * passenger pays. A booking without seat rows (older ones) rode whole once
 * the passenger confirmed it or their location proved it, else not at all.
 */
export function riddenSeats(booking: RiddenBooking): {
  rode: number;
  booked: number;
} {
  const counted = Number(booking.seatCount);
  const booked =
    counted > 0 ? counted : Math.max(1, booking.seats?.length ?? 0);
  if (!booking.seats?.length) {
    const rode =
      booking.passengerPresenceConfirmedAt != null ||
      booking.locationVerifiedAt != null;
    return { rode: rode ? booked : 0, booked };
  }
  const rode = booking.seats.filter((seat) =>
    seatCountsForCommission(seat, booking.locationVerifiedAt != null),
  ).length;
  return { rode, booked };
}

/**
 * [amount] (the booking's fare, for every seat booked) cut to the seats that
 * rode, in whole cents: four seats at 25 with one riding is 25, not 100.
 */
export function riddenShare(
  amount: string | number,
  { rode, booked }: { rode: number; booked: number },
): number {
  const cents = Math.round(Number(amount) * 100);
  if (!(rode > 0)) return 0;
  if (!(booked > 0) || rode >= booked) return cents / 100;
  return Math.round((cents * rode) / booked) / 100;
}
