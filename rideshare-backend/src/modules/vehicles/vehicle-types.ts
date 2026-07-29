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
  'sedan',
  'suv',
  'van',
  'truck',
  'bus',
  'motorcycle',
] as const;

export const DEFAULT_VEHICLE_TYPE = 'sedan';

export const VEHICLE_TYPE_CATALOG: Record<string, VehicleTypeTemplate> = {
  sedan: {
    type: 'sedan',
    label: { en: 'Sedan', ar: 'سيدان' },
    seats: 4,
    layout: {
      rows: 2,
      seatsPerRow: 3,
      seatsPerRowList: [1, 3],
      preventGenderMixing: false,
    },
  },
  suv: {
    type: 'suv',
    label: { en: 'SUV', ar: 'دفع رباعي' },
    seats: 5,
    layout: {
      rows: 2,
      seatsPerRow: 3,
      seatsPerRowList: [2, 3],
      preventGenderMixing: false,
    },
  },
  van: {
    type: 'van',
    label: { en: 'Van', ar: 'فان' },
    seats: 7,
    layout: {
      rows: 3,
      seatsPerRow: 3,
      seatsPerRowList: [2, 3, 2],
      preventGenderMixing: false,
    },
  },
  truck: {
    type: 'truck',
    label: { en: 'Truck', ar: 'شاحنة' },
    seats: 2,
    layout: { rows: 1, seatsPerRow: 2, preventGenderMixing: false },
  },
  bus: {
    type: 'bus',
    label: { en: 'Bus', ar: 'حافلة' },
    seats: 20,
    layout: {
      rows: 5,
      seatsPerRow: 4,
      seatsPerRowList: [4, 4, 4, 4, 4],
      preventGenderMixing: false,
    },
  },
  motorcycle: {
    type: 'motorcycle',
    label: { en: 'Motorcycle', ar: 'دراجة نارية' },
    seats: 1,
    layout: { rows: 1, seatsPerRow: 1, preventGenderMixing: false },
  },
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
