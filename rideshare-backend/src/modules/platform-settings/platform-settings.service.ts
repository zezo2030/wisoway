import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlatformSettingEntity } from '../../database/entities';

/**
 * The knobs an admin can turn from the dashboard, with their defaults. A key
 * with no row reads as its default, so a fresh database behaves sensibly.
 */
export const PLATFORM_SETTINGS = {
  /**
   * How much (%) a driver's rating drops for each instant ride they reach the
   * passenger late. 0 turns the cut off; drivers are still warned to hurry.
   */
  lateRatingPenaltyPercent: {
    key: 'instant.lateRatingPenaltyPercent',
    default: 2,
    min: 0,
    max: 50,
  },
  /**
   * How much (%) a rating drops when a driver or a passenger cancels an
   * instant ride after it was accepted. 0 turns the cut off.
   */
  cancelRatingPenaltyPercent: {
    key: 'instant.cancelRatingPenaltyPercent',
    default: 2,
    min: 0,
    max: 50,
  },
} as const;

export type PlatformSettingName = keyof typeof PLATFORM_SETTINGS;
export type PlatformSettingsView = Record<PlatformSettingName, number>;

/**
 * Read on every use (no cache), like the pricing row: an admin's change
 * applies to the very next ride.
 */
@Injectable()
export class PlatformSettingsService {
  constructor(
    @InjectRepository(PlatformSettingEntity)
    private readonly repo: Repository<PlatformSettingEntity>,
  ) {}

  async getNumber(name: PlatformSettingName): Promise<number> {
    const def = PLATFORM_SETTINGS[name];
    const row = await this.repo.findOne({ where: { key: def.key } });
    const value = Number(row?.value);
    return row && Number.isFinite(value) ? value : def.default;
  }

  async getAll(): Promise<PlatformSettingsView> {
    const names = Object.keys(PLATFORM_SETTINGS) as PlatformSettingName[];
    const values = await Promise.all(names.map((n) => this.getNumber(n)));
    return Object.fromEntries(
      names.map((n, i) => [n, values[i]]),
    ) as PlatformSettingsView;
  }

  /** Saves the given values (clamped to each knob's range) and returns all. */
  async update(
    patch: Partial<PlatformSettingsView>,
  ): Promise<PlatformSettingsView> {
    for (const [name, raw] of Object.entries(patch)) {
      const def = PLATFORM_SETTINGS[name as PlatformSettingName];
      if (!def || raw == null || !Number.isFinite(raw)) continue;
      const value = Math.min(def.max, Math.max(def.min, raw));
      await this.repo.save({ key: def.key, value: String(value) });
    }
    return this.getAll();
  }
}
