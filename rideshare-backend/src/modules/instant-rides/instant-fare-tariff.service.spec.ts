import { BadRequestException } from '@nestjs/common';
import { InstantFareTariffService } from './instant-fare-tariff.service';
import { fareTariffFor } from './instant-rides.constants';

/** An in-memory platform_settings table. */
function fakeRepo() {
  const rows = new Map<string, string>();
  return {
    rows,
    findOne: jest.fn(({ where: { key } }) =>
      Promise.resolve(rows.has(key) ? { key, value: rows.get(key) } : null),
    ),
    find: jest.fn(() =>
      Promise.resolve([...rows].map(([key, value]) => ({ key, value }))),
    ),
    save: jest.fn((row: { key: string; value: string }) => {
      rows.set(row.key, row.value);
      return Promise.resolve(row);
    }),
    delete: jest.fn(({ key }) => {
      rows.delete(key);
      return Promise.resolve({});
    }),
  };
}

describe('InstantFareTariffService', () => {
  let repo: ReturnType<typeof fakeRepo>;
  let service: InstantFareTariffService;

  beforeEach(() => {
    repo = fakeRepo();
    service = new InstantFareTariffService(repo as any);
  });

  it('uses the built-in tariff until an admin sets one', async () => {
    expect(await service.tariffFor('jod')).toEqual(fareTariffFor('JOD'));
  });

  it('prices with what the admin saved, keeping the fields left alone', async () => {
    await service.update('JOD', { base: 0.5, perKm: 0.35 });

    const tariff = await service.tariffFor('JOD');
    expect(tariff.base).toBe(0.5);
    expect(tariff.perKm).toBe(0.35);
    expect(tariff.waitPerMin).toBe(fareTariffFor('JOD').waitPerMin);
  });

  it('lists every currency and marks the edited ones', async () => {
    await service.update('SAR', { minimum: 15 });

    const list = await service.list();
    expect(list.find((t) => t.currency === 'SAR')).toMatchObject({
      minimum: 15,
      customized: true,
    });
    expect(list.find((t) => t.currency === 'JOD')?.customized).toBe(false);
  });

  it('refuses a negative price or a zero step', async () => {
    await expect(service.update('JOD', { perKm: -1 })).rejects.toThrow(
      BadRequestException,
    );
    await expect(service.update('JOD', { step: 0 })).rejects.toThrow(
      BadRequestException,
    );
  });

  it('goes back to the defaults on reset', async () => {
    await service.update('JOD', { base: 2 });
    await service.reset('JOD');

    expect((await service.tariffFor('JOD')).base).toBe(
      fareTariffFor('JOD').base,
    );
  });
});
