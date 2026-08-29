import { Logger } from '@nestjs/common';

export type SeatLayout = {
  rows: number;
  seatsPerRow: number;
  seatsPerRowList?: number[];
  preventGenderMixing?: boolean;
};

export type VehicleTypeTemplate = {
  type: string;
  label: {
    en: string;
    ar: string;
  };
  seats: number;
  layout: SeatLayout;
};

export const SUPPORTED_VEHICLE_TYPES = [
  'standard_car',
  'family_suv',
  'medium_bus',
  'large_bus',
] as const;

export const DEFAULT_VEHICLE_TYPE = 'standard_car';

/**
 * Builds a catalog entry from the per-row passenger seat counts, which are the
 * only numbers a human should have to get right. `seats` is derived rather than
 * declared so the advertised capacity can never drift from the layout that
 * generates the seat ids.
 *
 * Counts cover PASSENGER seats only — the driver's seat is drawn by the client
 * and is never bookable, so a "23 passenger" bus is 22 here.
 */
function buildTemplate(
  type: string,
  label: { en: string; ar: string },
  seatsPerRowList: number[],
): VehicleTypeTemplate {
  return {
    type,
    label,
    seats: seatsPerRowList.reduce((sum, count) => sum + count, 0),
    layout: {
      rows: seatsPerRowList.length,
      seatsPerRow: Math.max(...seatsPerRowList),
      seatsPerRowList: [...seatsPerRowList],
      preventGenderMixing: false,
    },
  };
}

/**
 * Row splits mirror the reference photos of each vehicle. Aisles and door gaps
 * are NOT encoded here — a row is just "how many bookable seats sit in it", and
 * the client positions them over the vehicle artwork.
 */
export const VEHICLE_TYPE_CATALOG: Record<string, VehicleTypeTemplate> = {
  // Front passenger beside the driver, three across the back.
  standard_car: buildTemplate(
    'standard_car',
    { en: 'Standard Car', ar: 'سيارة عادية' },
    [1, 3],
  ),
  // Front passenger, three-seat middle bench, two captain seats in the back.
  family_suv: buildTemplate(
    'family_suv',
    { en: 'Family SUV', ar: 'SUV عائلية' },
    [1, 3, 2],
  ),
  // Front passenger, then pair + aisle + single rows, three across the back.
  medium_bus: buildTemplate(
    'medium_bus',
    { en: 'Medium Bus', ar: 'باص متوسط' },
    [1, 3, 3, 3],
  ),
  // Six left-hand pairs, five staggered singles across the aisle (the boarding
  // door takes the sixth), and a four-wide rear bench. The last pair therefore
  // forms a row of two with no seat opposite it.
  large_bus: buildTemplate(
    'large_bus',
    { en: 'Large Bus', ar: 'باص كبير' },
    [1, 3, 3, 3, 3, 3, 2, 4],
  ),
};

export function countSeatsInLayout(layout: SeatLayout): number {
  if (
    Array.isArray(layout.seatsPerRowList) &&
    layout.seatsPerRowList.length > 0
  ) {
    return layout.seatsPerRowList.reduce((sum, count) => sum + count, 0);
  }

  return layout.rows * layout.seatsPerRow;
}

export function listVehicleTypeTemplates(): VehicleTypeTemplate[] {
  return SUPPORTED_VEHICLE_TYPES.map((type) =>
    cloneTemplate(VEHICLE_TYPE_CATALOG[type]),
  );
}

export function resolveVehicleTypeTemplate(
  type: string | null | undefined,
  logger?: Pick<Logger, 'warn'>,
): VehicleTypeTemplate & { usedFallback: boolean } {
  const normalizedType = type?.toLowerCase().trim();
  const template = normalizedType
    ? VEHICLE_TYPE_CATALOG[normalizedType]
    : undefined;

  if (template) {
    return { ...cloneTemplate(template), usedFallback: false };
  }

  logger?.warn(
    `Vehicle type "${type ?? 'unknown'}" has no seat layout template; using ${DEFAULT_VEHICLE_TYPE}`,
  );
  return {
    ...cloneTemplate(VEHICLE_TYPE_CATALOG[DEFAULT_VEHICLE_TYPE]),
    usedFallback: true,
  };
}

function cloneTemplate(template: VehicleTypeTemplate): VehicleTypeTemplate {
  return {
    ...template,
    label: { ...template.label },
    layout: {
      ...template.layout,
      seatsPerRowList: template.layout.seatsPerRowList
        ? [...template.layout.seatsPerRowList]
        : undefined,
    },
  };
}
