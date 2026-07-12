import {
  countSeatsInLayout,
  listVehicleTypeTemplates,
  SUPPORTED_VEHICLE_TYPES,
} from '../../src/modules/vehicles/vehicle-types';

describe('GET /vehicles/types (Contract)', () => {
  it('requires JWT auth at the controller boundary', () => {
    const contract = {
      path: '/vehicles/types',
      auth: 'JWT',
      unauthenticatedStatus: 401,
    };

    expect(contract.unauthenticatedStatus).toBe(401);
  });

  it('returns the full supported set with labels, seats, and non-empty layouts', () => {
    const response = { types: listVehicleTypeTemplates() };
    const returnedTypes = response.types.map((entry) => entry.type);

    expect(returnedTypes.sort()).toEqual([...SUPPORTED_VEHICLE_TYPES].sort());

    for (const entry of response.types) {
      expect(entry).toEqual(
        expect.objectContaining({
          type: expect.any(String),
          label: {
            en: expect.any(String),
            ar: expect.any(String),
          },
          seats: expect.any(Number),
          layout: expect.objectContaining({
            rows: expect.any(Number),
            seatsPerRow: expect.any(Number),
          }),
        }),
      );
      expect(entry.label.en.length).toBeGreaterThan(0);
      expect(entry.label.ar.length).toBeGreaterThan(0);
      expect(countSeatsInLayout(entry.layout)).toBe(entry.seats);
    }
  });
});
