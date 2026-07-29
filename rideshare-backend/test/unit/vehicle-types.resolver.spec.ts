import {
  countSeatsInLayout,
  resolveVehicleTypeTemplate,
  SUPPORTED_VEHICLE_TYPES,
} from '../../src/modules/vehicles/vehicle-types';

describe('vehicle type catalog resolver', () => {
  it.each(SUPPORTED_VEHICLE_TYPES)(
    'returns the configured template for %s',
    (type) => {
      const template = resolveVehicleTypeTemplate(type);

      expect(template.type).toBe(type);
      expect(template.usedFallback).toBe(false);
      expect(template.label.en).toBeTruthy();
      expect(template.label.ar).toBeTruthy();
      expect(countSeatsInLayout(template.layout)).toBe(template.seats);
    },
  );

  it('falls back and flags unknown vehicle types', () => {
    const logger = { warn: jest.fn() };

    const template = resolveVehicleTypeTemplate('spaceship', logger);

    expect(template.type).toBe('sedan');
    expect(template.usedFallback).toBe(true);
    expect(template.seats).toBe(4);
    expect(logger.warn).toHaveBeenCalledWith(
      expect.stringContaining('spaceship'),
    );
  });

  it('sedan uses 4 passenger seats in [1, 3] layout', () => {
    const template = resolveVehicleTypeTemplate('sedan');

    expect(template.seats).toBe(4);
    expect(template.layout.seatsPerRowList).toEqual([1, 3]);
    expect(countSeatsInLayout(template.layout)).toBe(4);
  });
});
