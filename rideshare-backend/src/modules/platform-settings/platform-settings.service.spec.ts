import { PlatformSettingsService } from './platform-settings.service';

describe('PlatformSettingsService', () => {
  let rows: Map<string, string>;
  let service: PlatformSettingsService;

  beforeEach(() => {
    rows = new Map();
    const repo = {
      findOne: jest.fn(({ where }: { where: { key: string } }) => {
        const value = rows.get(where.key);
        return Promise.resolve(
          value === undefined ? null : { key: where.key, value },
        );
      }),
      save: jest.fn((row: { key: string; value: string }) => {
        rows.set(row.key, row.value);
        return Promise.resolve(row);
      }),
    };
    service = new PlatformSettingsService(repo as never);
  });

  it('reads the default until an admin saves a value', async () => {
    expect(await service.getNumber('lateRatingPenaltyPercent')).toBe(2);
  });

  it('saves and returns the new value', async () => {
    const all = await service.update({ lateRatingPenaltyPercent: 5 });

    expect(all.lateRatingPenaltyPercent).toBe(5);
    expect(await service.getNumber('lateRatingPenaltyPercent')).toBe(5);
  });

  it('keeps values inside the allowed range', async () => {
    await service.update({ lateRatingPenaltyPercent: 400 });
    expect(await service.getNumber('lateRatingPenaltyPercent')).toBe(50);

    await service.update({ lateRatingPenaltyPercent: -3 });
    expect(await service.getNumber('lateRatingPenaltyPercent')).toBe(0);
  });
});
