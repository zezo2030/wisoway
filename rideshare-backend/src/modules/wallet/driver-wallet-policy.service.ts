import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlatformSettingEntity } from '../../database/entities';
import { PLATFORM_SETTINGS } from '../platform-settings/platform-settings.service';

/** Rates are public market data, never a conversion of a customer's balance. */
@Injectable()
export class DriverWalletPolicyService {
  constructor(
    @InjectRepository(PlatformSettingEntity)
    private readonly settings: Repository<PlatformSettingEntity>,
  ) {}

  /** The admin's floor (Operations settings), or its default when unset. */
  private async floor(
    name: 'minimumTopupJod' | 'minimumTopupSar',
  ): Promise<number> {
    const def = PLATFORM_SETTINGS[name];
    const row = await this.settings.findOne({ where: { key: def.key } });
    const value = Number(row?.value);
    return row && Number.isFinite(value) && value > 0 ? value : def.default;
  }

  async minimum(currency: string): Promise<number> {
    if (currency === 'JOD') return this.floor('minimumTopupJod');
    if (currency === 'SAR') return this.floor('minimumTopupSar');
    const base = await this.floor('minimumTopupJod');
    const key = 'wallet.fx.JOD';
    const row = await this.settings.findOne({ where: { key } });
    let data: { rates?: Record<string, number>; updated?: number } | undefined;
    try {
      data = row ? JSON.parse(row.value) : undefined;
    } catch {
      data = undefined;
    }
    if (!data?.updated || Date.now() - data.updated > 24 * 3600_000) {
      try {
        const response = await fetch('https://open.er-api.com/v6/latest/JOD', {
          signal: AbortSignal.timeout(8000),
        });
        const body = await response.json();
        if (
          !response.ok ||
          body.result !== 'success' ||
          body.base_code !== 'JOD' ||
          !Number.isFinite(body.time_last_update_unix) ||
          !body.rates
        )
          throw new Error('Invalid FX response');
        data = {
          rates: body.rates,
          updated: body.time_last_update_unix * 1000,
        };
        await this.settings.upsert({ key, value: JSON.stringify(data) }, [
          'key',
        ]);
      } catch {
        // An unavailable or stale feed must never invent a monetary threshold.
        if (!data?.updated || Date.now() - data.updated > 72 * 3600_000) {
          throw new ServiceUnavailableException(
            'تعذر تحديث سعر الصرف. حاول لاحقاً.',
          );
        }
      }
    }
    const rate = Number(data?.rates?.[currency]);
    if (
      !Number.isFinite(rate) ||
      rate <= 0 ||
      !data?.updated ||
      Date.now() - data.updated > 72 * 3600_000
    ) {
      throw new ServiceUnavailableException(
        'سعر صرف هذه العملة غير متاح حالياً.',
      );
    }
    return Math.ceil(base * rate * 100) / 100;
  }
}
