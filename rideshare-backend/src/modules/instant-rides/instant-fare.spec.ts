import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import {
  computeFare,
  DEFAULT_FARE_TARIFF,
  fareTariffFor,
  straightLineRoute,
  waitingCharge,
} from './instant-rides.constants';
import { RespondOfferDto } from './dto/respond-offer.dto';

describe('instant fare', () => {
  it('applies base + per km + per minute, rounded up to the step', () => {
    // SAR: 6 + 3*1.4 + 8*0.3 = 12.6 → 13
    expect(computeFare(3, 8, 'SAR')).toBe(13);
    // JOD (Jordan's meter): 0.45 + 12*0.316 + 20*0 = 4.242 → 4.25
    expect(computeFare(12, 20, 'JOD')).toBe(4.25);
  });

  it('never charges less than the minimum', () => {
    expect(computeFare(0.3, 1, 'SAR')).toBe(12);
    expect(computeFare(0.3, 1, 'JOD')).toBe(1.25);
  });

  it('does not bump a fare that already sits on a step', () => {
    // SAR: 6 + 10*1.4 + 0*0.3 = 20 exactly
    expect(computeFare(10, 0, 'SAR')).toBe(20);
  });

  it('falls back to the default tariff for an unlisted currency', () => {
    expect(fareTariffFor('TRY')).toBe(DEFAULT_FARE_TARIFF);
    expect(fareTariffFor('sar')).not.toBe(DEFAULT_FARE_TARIFF);
  });
});

describe('admin tariff', () => {
  it('prices with the tariff it is given over the default', () => {
    const tariff = { ...fareTariffFor('JOD'), base: 1, perKm: 0.5, step: 0.01 };
    expect(computeFare(10, 0, 'JOD', tariff)).toBe(6);
  });

  it('charges waiting only past the free minutes, per started minute', () => {
    const jod = fareTariffFor('JOD'); // 3 free minutes, 0.065 a minute
    expect(waitingCharge(jod, 2 * 60_000)).toBe(0);
    expect(waitingCharge(jod, 3 * 60_000)).toBe(0);
    // 5 min 10 s → 6 started minutes → 3 charged
    expect(waitingCharge(jod, 5 * 60_000 + 10_000)).toBe(0.2);
  });
});

describe('RespondOfferDto', () => {
  const errorsFor = (responseType: string) =>
    validate(plainToInstance(RespondOfferDto, { responseType, amount: 9 }));

  it('accepts accept and decline', async () => {
    expect(await errorsFor('accept')).toHaveLength(0);
    expect(await errorsFor('decline')).toHaveLength(0);
  });

  it('rejects a counter-offer — fares are fixed', async () => {
    expect(await errorsFor('counter')).not.toHaveLength(0);
  });
});

describe('straightLineRoute (no routing service answered)', () => {
  it('drives a short hop at city speed', () => {
    const r = straightLineRoute(5);
    expect(r.distanceKm).toBeCloseTo(6.5);
    expect(r.durationMin).toBe(Math.ceil((6.5 / 40) * 60));
  });

  it('drives between cities at highway speed', () => {
    // AlUla → Tabuk is ~236 km in a straight line.
    const r = straightLineRoute(236);
    expect(r.distanceKm).toBeCloseTo(306.8);
    expect(r.durationMin).toBeLessThan(4 * 60);
  });
});
