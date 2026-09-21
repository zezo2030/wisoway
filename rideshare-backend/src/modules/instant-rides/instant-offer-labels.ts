/**
 * Shared helpers for instant-offer push / pending-offer display labels.
 * Haversine + Arabic formatting used by dispatch push and pending-offer API.
 */

type LatLng = { latitude: number; longitude: number };

/** Average trip speed for duration estimate on the offer card. */
export const OFFER_TRIP_AVG_SPEED_KMH = 50;

export function haversineKm(a: LatLng, b: LatLng): number {
  const R = 6371;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLng = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return R * 2 * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function pointToLatLng(point: {
  coordinates: [number, number];
}): LatLng {
  const [lng, lat] = point.coordinates;
  return { latitude: lat, longitude: lng };
}

export function formatDistanceLabel(distanceKm: number): string {
  const rounded = Math.round(distanceKm * 10) / 10;
  const text =
    Number.isInteger(rounded) || Math.abs(rounded - Math.round(rounded)) < 0.05
      ? String(Math.round(rounded))
      : rounded.toFixed(1);
  return `${text} كم`;
}

export function formatDurationLabel(durationMinutes: number): string {
  const mins = Math.max(1, Math.round(durationMinutes));
  if (mins < 60) return `${mins} د`;
  const hours = Math.floor(mins / 60);
  const rem = mins % 60;
  if (rem === 0) return `${hours} س`;
  return `${hours} س ${rem} د`;
}

export function formatEarningsLabel(amount: string, currency: string): string {
  const symbol =
    currency === 'JOD' || currency === 'د.أ'
      ? 'د.أ'
      : currency === 'SAR' || currency === 'ر.س'
        ? 'ر.س'
        : currency;
  const numeric = Number(amount);
  const formatted = Number.isFinite(numeric)
    ? numeric.toFixed(2)
    : amount || '—';
  return `${formatted} ${symbol}`;
}

export function formatSeatCountLabel(seatCount: number): string {
  const n = Math.max(1, Math.round(seatCount));
  return `${n} راكب`;
}

export function buildInstantOfferRouteMetrics(input: {
  fromPoint: { coordinates: [number, number] };
  toPoint: { coordinates: [number, number] };
  passengerFare?: string | null;
  fareEstimate?: string | null;
  currency: string;
  seatCount?: number | null;
}): {
  distanceKm: string;
  durationMinutes: string;
  distanceLabel: string;
  durationLabel: string;
  earningsLabel: string;
  tripTypeLabel: string;
  seatCount: string;
  seatCountLabel: string;
} {
  const from = pointToLatLng(input.fromPoint);
  const to = pointToLatLng(input.toPoint);
  const distanceKm = haversineKm(from, to);
  const durationMinutes = Math.max(
    1,
    Math.round((distanceKm / OFFER_TRIP_AVG_SPEED_KMH) * 60),
  );
  const fare = input.passengerFare ?? input.fareEstimate ?? '';
  const seats = input.seatCount ?? 1;
  return {
    distanceKm: String(Math.round(distanceKm * 10) / 10),
    durationMinutes: String(durationMinutes),
    distanceLabel: formatDistanceLabel(distanceKm),
    durationLabel: formatDurationLabel(durationMinutes),
    earningsLabel: formatEarningsLabel(fare, input.currency),
    tripTypeLabel: 'مباشرة',
    seatCount: String(seats),
    seatCountLabel: formatSeatCountLabel(seats),
  };
}
