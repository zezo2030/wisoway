import { BadRequestException } from '@nestjs/common';

/**
 * A seat the driver took out of a shared trip (kept for themselves, a child,
 * luggage…). It stays in `trip.seats` so every seat keeps its place in the
 * layout, but it is never bookable and not counted in `totalSeats`.
 */
export const CLOSED_SEAT_STATUS = 'closed';

export interface SeatLayoutShape {
  rows: number;
  seatsPerRow: number;
  seatsPerRowList?: number[];
}

/** Every seat id ("row-col") of a layout, in display order (front row first). */
export function layoutSeatNumbers(
  layout: SeatLayoutShape | null | undefined,
): string[] {
  if (!layout) return [];
  const rows =
    layout.seatsPerRowList && layout.seatsPerRowList.length > 0
      ? layout.seatsPerRowList
      : Array.from({ length: layout.rows || 0 }, () => layout.seatsPerRow || 0);
  const ids: string[] = [];
  rows.forEach((count, row) => {
    for (let col = 0; col < count; col++) ids.push(`${row}-${col}`);
  });
  return ids;
}

/**
 * Which seats close when the driver only says how many to offer: the front
 * row first — the seat beside the driver is the one most often kept back —
 * then from the rear of the cabin forwards.
 */
export function defaultClosedSeats(
  layout: SeatLayoutShape,
  openCount: number,
): string[] {
  const ids = layoutSeatNumbers(layout);
  const front = ids.filter((id) => id.startsWith('0-'));
  const rest = ids.filter((id) => !id.startsWith('0-')).reverse();
  return [...front, ...rest].slice(0, Math.max(0, ids.length - openCount));
}

/**
 * The closed seats for a new trip, from the driver's explicit choice when
 * given, else from the seat count. Throws on seats outside the layout, or on
 * a choice that leaves nothing to book.
 */
export function resolveClosedSeats(
  layout: SeatLayoutShape,
  input: { closedSeatNumbers?: string[]; availableSeats?: number },
): string[] {
  const ids = layoutSeatNumbers(layout);
  const max = ids.length;

  if (input.closedSeatNumbers) {
    const closed = [...new Set(input.closedSeatNumbers)];
    const unknown = closed.filter((id) => !ids.includes(id));
    if (unknown.length > 0) {
      throw new BadRequestException(
        `closedSeatNumbers not in the vehicle layout: ${unknown.join(', ')}`,
      );
    }
    const open = max - closed.length;
    if (open < 1) {
      throw new BadRequestException('At least one seat must stay available');
    }
    if (input.availableSeats != null && input.availableSeats !== open) {
      throw new BadRequestException(
        'availableSeats does not match the seats left open',
      );
    }
    return closed;
  }

  const requested = input.availableSeats ?? max;
  if (requested < 1 || requested > max) {
    throw new BadRequestException(
      `availableSeats must be between 1 and ${max}`,
    );
  }
  return defaultClosedSeats(layout, requested);
}

/** Every layout seat, the closed ones marked so; the rest open to book. */
export function buildTripSeats(
  layout: SeatLayoutShape | null | undefined,
  closedSeatNumbers: Iterable<string>,
) {
  const closed = new Set(closedSeatNumbers);
  return layoutSeatNumbers(layout).map((seatNumber) => ({
    seatNumber,
    userId: null,
    userName: null,
    gender: null,
    bookedAt: null,
    status: closed.has(seatNumber) ? CLOSED_SEAT_STATUS : 'available',
  }));
}
