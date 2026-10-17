import { Column, Entity, PrimaryColumn, UpdateDateColumn } from 'typeorm';

/**
 * One operational knob the admin can turn from the dashboard without a
 * deploy (see PlatformSettingsService for the known keys and defaults).
 */
@Entity({ name: 'platform_settings' })
export class PlatformSettingEntity {
  @PrimaryColumn({ type: 'varchar', length: 64 })
  key: string;

  @Column({ type: 'text' })
  value: string;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt: Date;
}
