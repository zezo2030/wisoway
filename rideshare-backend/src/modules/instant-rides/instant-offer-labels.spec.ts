import {
  buildInstantOfferRouteMetrics,
  formatDistanceLabel,
  formatDurationLabel,
  formatEarningsLabel,
  formatSeatCountLabel,
  buildInstantOfferPushText,
  normalizeOfferLocale,
} from './instant-offer-labels';

describe('instant-offer-labels', () => {
  it('formats distance and duration labels', () => {
    expect(formatDistanceLabel(95)).toBe('95 كم');
    expect(formatDistanceLabel(12.34)).toBe('12.3 كم');
    expect(formatDurationLabel(45)).toBe('45 د');
    expect(formatDurationLabel(80)).toBe('1 س 20 د');
    expect(formatDurationLabel(120)).toBe('2 س');
  });

  it('formats JOD and SAR earnings', () => {
    expect(formatEarningsLabel('18', 'JOD')).toBe('18.00 د.أ');
    expect(formatEarningsLabel('350', 'SAR')).toBe('350.00 ر.س');
  });

  it('formats seat count label', () => {
    expect(formatSeatCountLabel(2)).toBe('2 راكب');
  });

  it('builds route metrics from Amman→Irbid-ish points', () => {
    // Approx Sports City Circle → Irbid bus complex
    const metrics = buildInstantOfferRouteMetrics({
      fromPoint: { type: 'Point', coordinates: [35.907, 31.981] } as {
        coordinates: [number, number];
      },
      toPoint: { type: 'Point', coordinates: [35.85, 32.555] } as {
        coordinates: [number, number];
      },
      passengerFare: '18.00',
      currency: 'JOD',
      seatCount: 2,
    });
    expect(Number(metrics.distanceKm)).toBeGreaterThan(50);
    expect(Number(metrics.durationMinutes)).toBeGreaterThan(30);
    expect(metrics.distanceLabel).toContain('كم');
    expect(metrics.earningsLabel).toBe('18.00 د.أ');
    expect(metrics.tripTypeLabel).toBe('مباشرة');
    expect(metrics.seatCount).toBe('2');
    expect(metrics.seatCountLabel).toBe('2 راكب');
  });
});

describe('instant-offer-labels (en)', () => {
  it('formats English labels when the driver app language is English', () => {
    expect(formatDistanceLabel(95, 'en')).toBe('95 km');
    expect(formatDurationLabel(80, 'en')).toBe('1 h 20 min');
    expect(formatEarningsLabel('18', 'JOD', 'en')).toBe('18.00 JOD');
    expect(formatSeatCountLabel(2, 'en')).toBe('2 passengers');
  });

  it('normalizes locale strings and builds English push text', () => {
    expect(normalizeOfferLocale('en-US')).toBe('en');
    expect(normalizeOfferLocale('ar')).toBe('ar');
    expect(normalizeOfferLocale(undefined)).toBe('ar');
    const text = buildInstantOfferPushText({
      fromName: 'Amman',
      toName: 'Irbid',
      earningsLabel: '18.00 JOD',
      locale: 'en',
    });
    expect(text.title).toBe('New direct trip');
    expect(text.body).toContain('From Amman to Irbid');
  });

  describe('driver leg to the pickup', () => {
    const route = {
      // ~11 km apart, enough to keep the trip and pickup figures distinct.
      fromPoint: { coordinates: [35.9, 31.95] },
      toPoint: { coordinates: [36.0, 32.0] },
      currency: 'JOD',
      passengerFare: '12',
    };

    it('reports the pickup leg separately from the trip distance', () => {
      const metrics = buildInstantOfferRouteMetrics({
        ...route,
        pickupDistanceMeters: 2400,
      });
      expect(metrics.pickupDistanceKm).toBe('2.4');
      expect(metrics.pickupDistanceLabel).toBe('2.4 كم');
      // The trip itself is unchanged by how far away the driver happens to be.
      expect(metrics.pickupDistanceLabel).not.toBe(metrics.distanceLabel);
    });

    it('localizes the pickup label with the rest of the card', () => {
      const metrics = buildInstantOfferRouteMetrics({
        ...route,
        pickupDistanceMeters: 800,
        locale: 'en',
      });
      expect(metrics.pickupDistanceLabel).toBe('0.8 km');
    });

    it('leaves the pickup leg empty when the driver location is unknown', () => {
      // These values are spread into an FCM data payload, which only carries
      // strings — an absent leg has to be an empty string, never undefined.
      for (const pickupDistanceMeters of [undefined, null]) {
        const metrics = buildInstantOfferRouteMetrics({
          ...route,
          pickupDistanceMeters,
        });
        expect(metrics.pickupDistanceKm).toBe('');
        expect(metrics.pickupDistanceLabel).toBe('');
      }
    });
  });
});
