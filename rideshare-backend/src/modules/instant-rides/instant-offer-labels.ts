/**
 * Shared helpers for instant-offer push / pending-offer display labels.
 * Haversine + locale-aware (ar/en) formatting used by dispatch push and the
 * pending-offer API. Arabic is the default; English is used when the driver's
 * app language is English.
 */

type LatLng = { latitude: number; longitude: number };

export type OfferLocale = 'ar' | 'en';

/** Average trip speed for duration estimate on the offer card. */
export const OFFER_TRIP_AVG_SPEED_KMH = 50;

/** Normalize any locale-ish string ("en-US", "EN", null) to 'ar' | 'en'. */
export function normalizeOfferLocale(raw?: string | null): OfferLocale {
  return typeof raw === 'string' && raw.trim().toLowerCase().startsWith('en')
    ? 'en'
    : 'ar';
}

const STRINGS: Record<
  OfferLocale,
  {
    km: string;
    minute: string;
    hour: string;
    passenger: string;
    direct: string;
    newInstantTrip: string;
    directNoStops: string;
    from: string;
    to: string;
    currency: Record<string, string>;
  }
> = {
  ar: {
    km: 'كم',
    minute: 'د',
    hour: 'س',
    passenger: 'راكب',
    direct: 'مباشرة',
    newInstantTrip: 'رحلة مباشرة جديدة',
    directNoStops: 'رحلة مباشرة بدون توقف',
    from: 'من',
    to: 'إلى',
    currency: { JOD: 'د.أ', 'د.أ': 'د.أ', SAR: 'ر.س', 'ر.س': 'ر.س' },
  },
  en: {
    km: 'km',
    minute: 'min',
    hour: 'h',
    passenger: 'passengers',
    direct: 'Direct',
    newInstantTrip: 'New direct trip',
    directNoStops: 'Direct trip, no stops',
    from: 'From',
    to: 'to',
    currency: { JOD: 'JOD', 'د.أ': 'JOD', SAR: 'SAR', 'ر.س': 'SAR' },
  },
};

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

export function formatDistanceLabel(
  distanceKm: number,
  locale: OfferLocale = 'ar',
): string {
  const rounded = Math.round(distanceKm * 10) / 10;
  const text =
    Number.isInteger(rounded) || Math.abs(rounded - Math.round(rounded)) < 0.05
      ? String(Math.round(rounded))
      : rounded.toFixed(1);
  return `${text} ${STRINGS[locale].km}`;
}

export function formatDurationLabel(
  durationMinutes: number,
  locale: OfferLocale = 'ar',
): string {
  const s = STRINGS[locale];
  const mins = Math.max(1, Math.round(durationMinutes));
  if (mins < 60) return `${mins} ${s.minute}`;
  const hours = Math.floor(mins / 60);
  const rem = mins % 60;
  if (rem === 0) return `${hours} ${s.hour}`;
  return `${hours} ${s.hour} ${rem} ${s.minute}`;
}

export function formatEarningsLabel(
  amount: string,
  currency: string,
  locale: OfferLocale = 'ar',
): string {
  const symbol = STRINGS[locale].currency[currency] ?? currency;
  const numeric = Number(amount);
  const formatted = Number.isFinite(numeric)
    ? numeric.toFixed(2)
    : amount || '—';
  return `${formatted} ${symbol}`;
}

export function formatSeatCountLabel(
  seatCount: number,
  locale: OfferLocale = 'ar',
): string {
  const n = Math.max(1, Math.round(seatCount));
  return `${n} ${STRINGS[locale].passenger}`;
}

export function formatTripTypeLabel(locale: OfferLocale = 'ar'): string {
  return STRINGS[locale].direct;
}

/** Title + body for the driver push, in the driver's app language. */
export function buildInstantOfferPushText(input: {
  fromName: string;
  toName: string;
  earningsLabel: string;
  locale?: OfferLocale;
}): { title: string; body: string } {
  const s = STRINGS[input.locale ?? 'ar'];
  return {
    title: s.newInstantTrip,
    body: [
      s.directNoStops,
      `${s.from} ${input.fromName} ${s.to} ${input.toName}`,
      input.earningsLabel,
    ].join('\n'),
  };
}

export function buildInstantOfferRouteMetrics(input: {
  fromPoint: { coordinates: [number, number] };
  toPoint: { coordinates: [number, number] };
  passengerFare?: string | null;
  fareEstimate?: string | null;
  currency: string;
  seatCount?: number | null;
  locale?: OfferLocale;
  /**
   * Straight-line metres from the driver to the pickup, when the caller knows
   * where the driver is. The offer card needs this separately from the trip
   * distance: "how far do I drive to reach them" is what decides whether the
   * job is worth taking, and it is not derivable from the route alone.
   */
  pickupDistanceMeters?: number | null;
}): {
  distanceKm: string;
  durationMinutes: string;
  pickupDistanceKm: string;
  pickupDistanceLabel: string;
  distanceLabel: string;
  durationLabel: string;
  earningsLabel: string;
  tripType: string;
  tripTypeLabel: string;
  seatCount: string;
  seatCountLabel: string;
  locale: OfferLocale;
} {
  const locale = input.locale ?? 'ar';
  const from = pointToLatLng(input.fromPoint);
  const to = pointToLatLng(input.toPoint);
  const distanceKm = haversineKm(from, to);
  const durationMinutes = Math.max(
    1,
    Math.round((distanceKm / OFFER_TRIP_AVG_SPEED_KMH) * 60),
  );
  const fare = input.passengerFare ?? input.fareEstimate ?? '';
  const seats = input.seatCount ?? 1;
  const pickupMeters = input.pickupDistanceMeters;
  const hasPickup = typeof pickupMeters === 'number' && pickupMeters >= 0;
  const pickupKm = hasPickup ? pickupMeters / 1000 : null;
  return {
    distanceKm: String(Math.round(distanceKm * 10) / 10),
    durationMinutes: String(durationMinutes),
    pickupDistanceKm:
      pickupKm == null ? '' : String(Math.round(pickupKm * 10) / 10),
    pickupDistanceLabel:
      pickupKm == null ? '' : formatDistanceLabel(pickupKm, locale),
    distanceLabel: formatDistanceLabel(distanceKm, locale),
    durationLabel: formatDurationLabel(durationMinutes, locale),
    earningsLabel: formatEarningsLabel(fare, input.currency, locale),
    tripType: 'direct',
    tripTypeLabel: formatTripTypeLabel(locale),
    seatCount: String(seats),
    seatCountLabel: formatSeatCountLabel(seats, locale),
    locale,
  };
}
