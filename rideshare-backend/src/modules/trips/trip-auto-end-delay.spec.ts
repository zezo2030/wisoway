import {
  computeTripAutoEndDelayMs,
  tripAutoEndTimes,
} from './trip-auto-start.util';

const HOUR = 60 * 60 * 1000;
const MINUTE = 60 * 1000;

describe('computeTripAutoEndDelayMs', () => {
  const trip = {
    departureTime: new Date(),
    fromPoint: { coordinates: [35.9, 31.9] },
    toPoint: { coordinates: [35.9, 31.9] },
  };

  it('adds half an hour to a short trip', () => {
    expect(
      computeTripAutoEndDelayMs({ ...trip, remainingDurationSeconds: 1800 }),
    ).toBe(HOUR);
  });

  it('adds a quarter to a long trip', () => {
    expect(
      computeTripAutoEndDelayMs({
        ...trip,
        remainingDurationSeconds: 4 * 3600,
      }),
    ).toBe(5 * HOUR);
  });

  it('estimates from the distance when tracking has no estimate yet', () => {
    const delay = computeTripAutoEndDelayMs({
      ...trip,
      remainingDurationSeconds: null,
      // About 111 km north, so around 2 h by road.
      toPoint: { coordinates: [35.9, 32.9] },
    });

    expect(delay).toBeGreaterThan(2 * HOUR);
    expect(delay).toBeLessThan(3 * HOUR);
  });

  it('never runs past the fallback after departure', () => {
    const delay = computeTripAutoEndDelayMs({
      ...trip,
      departureTime: new Date(Date.now() - 23 * HOUR),
      remainingDurationSeconds: 5 * 3600,
    });

    expect(delay).toBeLessThanOrEqual(HOUR);
    expect(delay).toBeGreaterThan(HOUR - MINUTE);
  });
});

describe('tripAutoEndTimes', () => {
  // About 2 km apart, the size of the short trip reported on 2026-11-07.
  const trip = {
    departureTime: new Date('2026-11-06T20:53:00Z'),
    tripStartedAt: new Date('2026-11-06T20:53:00Z'),
    fromPoint: { coordinates: [37.9, 26.65] },
    toPoint: { coordinates: [37.9, 26.668] },
  };
  const startedAt = trip.tripStartedAt.getTime();

  it('makes a short trip due half an hour past its estimate', () => {
    const { dueAt } = tripAutoEndTimes(trip);

    expect(dueAt - startedAt).toBeGreaterThan(32 * MINUTE);
    expect(dueAt - startedAt).toBeLessThan(35 * MINUTE);
  });

  it('holds a car still driving for at most twice that', () => {
    const { lastCallAt } = tripAutoEndTimes(trip);

    expect(lastCallAt - startedAt).toBeGreaterThan(64 * MINUTE);
    expect(lastCallAt - startedAt).toBeLessThan(70 * MINUTE);
  });

  it('counts from departure when the start time is missing', () => {
    expect(tripAutoEndTimes({ ...trip, tripStartedAt: null }).dueAt).toBe(
      tripAutoEndTimes(trip).dueAt,
    );
  });

  it('never runs past the fallback after departure', () => {
    const { dueAt, lastCallAt } = tripAutoEndTimes({
      ...trip,
      tripStartedAt: new Date(trip.departureTime.getTime() + 23.9 * HOUR),
    });
    const fallbackAt = trip.departureTime.getTime() + 24 * HOUR;

    expect(dueAt).toBe(fallbackAt);
    expect(lastCallAt).toBe(fallbackAt);
  });
});
