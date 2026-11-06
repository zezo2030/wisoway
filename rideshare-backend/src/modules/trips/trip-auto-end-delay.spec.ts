import { computeTripAutoEndDelayMs } from './trip-auto-start.util';

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
