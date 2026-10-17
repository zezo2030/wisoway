import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PlatformSettingEntity } from '../../database/entities';
import { PlatformSettingsService } from './platform-settings.service';
import { AdminPlatformSettingsController } from './admin-platform-settings.controller';

/** Dashboard-editable operational settings (see PLATFORM_SETTINGS). */
@Module({
  imports: [TypeOrmModule.forFeature([PlatformSettingEntity])],
  controllers: [AdminPlatformSettingsController],
  providers: [PlatformSettingsService],
  exports: [PlatformSettingsService],
})
export class PlatformSettingsModule {}
