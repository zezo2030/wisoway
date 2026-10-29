import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Like, Repository } from 'typeorm';
import { PlatformSettingEntity } from '../../database/entities';
import {
  FARE_TARIFFS,
  FareTariff,
  fareTariffFor,
} from './instant-rides.constants';

const KEY_PREFIX = 'instant.tariff.';
const FIELDS: (keyof FareTariff)[] = [
  'base',
  'perKm',
  'perMin',
  'waitPerMin',
  'freeWaitMin',
  'minimum',
  'step',
];

export interface FareTariffView extends FareTariff {
  currency: string;
  /** True once an admin saved this currency; false while on the defaults. */
  customized: boolean;
}

/**
 * The instant-ride tariff per currency, set by admins from the dashboard.
 * A currency an admin never touched uses the defaults in
 * instant-rides.constants. Read on every quote (no cache), so a change
 * prices the very next request.
 */
@Injectable()
export class InstantFareTariffService {
  constructor(
    @InjectRepository(PlatformSettingEntity)
    private readonly repo: Repository<PlatformSettingEntity>,
  ) {}

  async tariffFor(currency: string): Promise<FareTariff> {
    const code = currency?.toUpperCase();
    const row = await this.repo.findOne({ where: { key: KEY_PREFIX + code } });
    return merge(fareTariffFor(code), row?.value);
  }

  /** Every currency with a default or a saved tariff. */
  async list(): Promise<FareTariffView[]> {
    const rows = await this.repo.find({
      where: { key: Like(`${KEY_PREFIX}%`) },
    });
    const saved = new Map(
      rows.map((r) => [r.key.slice(KEY_PREFIX.length), r.value]),
    );
    const codes = [...new Set([...Object.keys(FARE_TARIFFS), ...saved.keys()])];
    return codes.map((currency) => ({
      currency,
      ...merge(fareTariffFor(currency), saved.get(currency)),
      customized: saved.has(currency),
    }));
  }

  async update(
    currency: string,
    patch: Partial<FareTariff>,
  ): Promise<FareTariffView> {
    const code = currency?.toUpperCase();
    if (!/^[A-Z]{3}$/.test(code ?? '')) {
      throw new BadRequestException('Unknown currency');
    }
    const next = { ...(await this.tariffFor(code)) };
    for (const field of FIELDS) {
      const value = patch[field];
      if (value == null) continue;
      if (!Number.isFinite(value) || value < 0) {
        throw new BadRequestException(`${field} must be zero or more`);
      }
      next[field] = value;
    }
    if (next.step <= 0) throw new BadRequestException('step must be above 0');
    await this.repo.save({
      key: KEY_PREFIX + code,
      value: JSON.stringify(next),
    });
    return { currency: code, ...next, customized: true };
  }

  /** Back to the built-in defaults for this currency. */
  async reset(currency: string): Promise<FareTariffView> {
    const code = currency?.toUpperCase();
    await this.repo.delete({ key: KEY_PREFIX + code });
    return { currency: code, ...fareTariffFor(code), customized: false };
  }
}

/** The saved fields over the defaults; a bad or missing value keeps the default. */
function merge(defaults: FareTariff, raw?: string | null): FareTariff {
  if (!raw) return { ...defaults };
  let saved: Record<string, unknown> = {};
  try {
    saved = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return { ...defaults };
  }
  const out = { ...defaults };
  for (const field of FIELDS) {
    const value = Number(saved[field]);
    if (saved[field] != null && Number.isFinite(value) && value >= 0) {
      out[field] = value;
    }
  }
  if (out.step <= 0) out.step = defaults.step;
  return out;
}
