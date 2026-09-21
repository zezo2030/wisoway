import {
  buildInstantOfferRouteMetrics,
  formatDistanceLabel,
  formatDurationLabel,
  formatEarningsLabel,
  formatSeatCountLabel,
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
