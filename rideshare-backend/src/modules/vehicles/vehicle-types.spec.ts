import {
  DEFAULT_VEHICLE_TYPE,
  SUPPORTED_VEHICLE_TYPES,
  countSeatsInLayout,
  listVehicleTypeTemplates,
  resolveVehicleTypeTemplate,
} from './vehicle-types';

/**
 * The catalog is the single source of truth for how many passenger seats a
 * vehicle has and which rows they sit in. Seat ids (`row-col`) are generated
 * from these layouts, so a wrong row split silently corrupts every booking on
 * that trip — hence the exhaustive assertions below.
 */
describe('vehicle-types catalog', () => {
  const EXPECTED = [
    { type: 'standard_car', seats: 4, rows: [1, 3] },
    { type: 'family_suv', seats: 6, rows: [1, 3, 2] },
    { type: 'medium_bus', seats: 10, rows: [1, 3, 3, 3] },
    { type: 'large_bus', seats: 22, rows: [1, 3, 3, 3, 3, 3, 2, 4] },
  ];

  it('exposes exactly the five supported types, in catalog order', () => {
    expect([...SUPPORTED_VEHICLE_TYPES]).toEqual(EXPECTED.map((e) => e.type));
    expect(listVehicleTypeTemplates().map((t) => t.type)).toEqual(
      EXPECTED.map((e) => e.type),
    );
  });

  it.each(EXPECTED)(
    '$type seats $seats passengers across rows $rows',
    ({ type, seats, rows }) => {
      const template = resolveVehicleTypeTemplate(type);

      expect(template.usedFallback).toBe(false);
      expect(template.seats).toBe(seats);
      expect(template.layout.seatsPerRowList).toEqual(rows);
      expect(template.layout.rows).toBe(rows.length);
    },
  );

  it('keeps declared seat count in sync with the layout for every type', () => {
    for (const template of listVehicleTypeTemplates()) {
      expect(countSeatsInLayout(template.layout)).toBe(template.seats);
    }
  });

  it('labels every type in both English and Arabic', () => {
    for (const template of listVehicleTypeTemplates()) {
      expect(template.label.en).toBeTruthy();
      expect(template.label.ar).toBeTruthy();
    }
  });

  it('normalizes case and surrounding whitespace', () => {
    expect(resolveVehicleTypeTemplate('  FAMILY_SUV ').type).toBe('family_suv');
  });

  it.each([
    'sedan',
    'suv',
    'van',
    'truck',
    'bus',
    'motorcycle',
    'small_bus',
    '',
    null,
  ])(
    'falls back to the default type for retired/unknown value %p',
    (retired) => {
      const warn = jest.fn();
      const template = resolveVehicleTypeTemplate(retired, { warn });

      expect(template.usedFallback).toBe(true);
      expect(template.type).toBe(DEFAULT_VEHICLE_TYPE);
      expect(warn).toHaveBeenCalled();
    },
  );

  it('returns defensive copies so callers cannot mutate the catalog', () => {
    const first = resolveVehicleTypeTemplate('standard_car');
    first.layout.seatsPerRowList!.push(99);
    first.label.ar = 'mutated';

    const second = resolveVehicleTypeTemplate('standard_car');
    expect(second.layout.seatsPerRowList).toEqual([1, 3]);
    expect(second.label.ar).not.toBe('mutated');
  });
});
