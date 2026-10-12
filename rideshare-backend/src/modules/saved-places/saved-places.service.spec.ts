import { BadRequestException, NotFoundException } from '@nestjs/common';
import { SavedPlaceKind } from '../../database/entities/saved-place.entity';
import { MAX_CUSTOM_PLACES, SavedPlacesService } from './saved-places.service';

describe('SavedPlacesService', () => {
  let rows: any[];
  let service: SavedPlacesService;

  const matches = (row: any, where: any) =>
    Object.entries(where).every(([k, v]) => row[k] === v);

  beforeEach(() => {
    rows = [];
    // Models the unique (userId, kind, label) index behind upsert.
    const repo = {
      find: jest.fn(async ({ where }: any) =>
        rows.filter((r) => matches(r, where)),
      ),
      findOne: jest.fn(
        async ({ where }: any) => rows.find((r) => matches(r, where)) ?? null,
      ),
      findOneOrFail: jest.fn(async ({ where }: any) =>
        rows.find((r) => matches(r, where)),
      ),
      count: jest.fn(
        async ({ where }: any) => rows.filter((r) => matches(r, where)).length,
      ),
      upsert: jest.fn(async (values: any) => {
        const existing = rows.find(
          (r) =>
            r.userId === values.userId &&
            r.kind === values.kind &&
            r.label === values.label,
        );
        if (existing) Object.assign(existing, values);
        else rows.push({ id: `p${rows.length + 1}`, ...values });
      }),
      delete: jest.fn(async (where: any) => {
        const before = rows.length;
        rows = rows.filter((r) => !matches(r, where));
        return { affected: before - rows.length };
      }),
    };
    service = new SavedPlacesService(repo as any);
  });

  const place = (overrides: any = {}) => ({
    kind: SavedPlaceKind.HOME,
    name: 'Abdali',
    latitude: 31.96,
    longitude: 35.91,
    ...overrides,
  });

  it('keeps one Home per user, moving it on a second save', async () => {
    await service.upsert('u1', place());
    const moved = await service.upsert('u1', place({ name: 'Sweifieh' }));
    expect(rows).toHaveLength(1);
    expect(moved.name).toBe('Sweifieh');
  });

  it('ignores any label sent for Home and Work', async () => {
    await service.upsert('u1', place({ label: 'المنزل' }));
    await service.upsert('u1', place({ label: 'Home' }));
    expect(rows).toEqual([expect.objectContaining({ label: '' })]);
  });

  it('matches custom places by label', async () => {
    await service.upsert(
      'u1',
      place({ kind: SavedPlaceKind.CUSTOM, label: 'Gym' }),
    );
    await service.upsert(
      'u1',
      place({ kind: SavedPlaceKind.CUSTOM, label: 'Uni' }),
    );
    await service.upsert(
      'u1',
      place({ kind: SavedPlaceKind.CUSTOM, label: 'Gym', name: 'New gym' }),
    );
    expect(rows).toHaveLength(2);
    expect(rows.find((r) => r.label === 'Gym').name).toBe('New gym');
  });

  it('requires a label on a custom place', async () => {
    await expect(
      service.upsert('u1', place({ kind: SavedPlaceKind.CUSTOM, label: ' ' })),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('caps the number of custom places', async () => {
    for (let i = 0; i < MAX_CUSTOM_PLACES; i++) {
      await service.upsert(
        'u1',
        place({ kind: SavedPlaceKind.CUSTOM, label: `p${i}` }),
      );
    }
    await expect(
      service.upsert(
        'u1',
        place({ kind: SavedPlaceKind.CUSTOM, label: 'one more' }),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    // Moving an existing one is still allowed at the cap.
    await expect(
      service.upsert(
        'u1',
        place({ kind: SavedPlaceKind.CUSTOM, label: 'p0', name: 'moved' }),
      ),
    ).resolves.toMatchObject({ name: 'moved' });
  });

  it('lists Home, then Work, then named places', async () => {
    await service.upsert(
      'u1',
      place({ kind: SavedPlaceKind.CUSTOM, label: 'Gym' }),
    );
    await service.upsert('u1', place({ kind: SavedPlaceKind.WORK }));
    await service.upsert('u1', place());
    const kinds = (await service.list('u1')).map((p) => p.kind);
    expect(kinds).toEqual([
      SavedPlaceKind.HOME,
      SavedPlaceKind.WORK,
      SavedPlaceKind.CUSTOM,
    ]);
  });

  it("never deletes another user's place", async () => {
    const mine = await service.upsert('u1', place());
    await expect(service.remove('u2', mine.id)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(rows).toHaveLength(1);
    await service.remove('u1', mine.id);
    expect(rows).toHaveLength(0);
  });
});
