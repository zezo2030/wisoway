import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/services/localization_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../../widgets/settings/settings_switch_tile.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _locationSharing = false;
  bool _showOnlineStatus = false;
  bool _showRating = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = SettingsService();
    _locationSharing = await settings.isLocationSharingEnabled();
    _showOnlineStatus = await settings.isShowOnlineStatus();
    _showRating = await settings.isShowRating();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = context.watch<LocalizationService>();
    final isArabic = localizationService.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إعدادات الخصوصية' : 'Privacy Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: isArabic ? 'إعدادات الخصوصية' : 'Privacy Settings',
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.location,
                      title: isArabic ? 'مشاركة الموقع' : 'Location Sharing',
                      subtitle: isArabic
                          ? 'السماح بمشاركة موقعك أثناء الرحلة'
                          : 'Allow sharing your location during rides',
                      value: _locationSharing,
                      onChanged: (value) {
                        SettingsService().setLocationSharingEnabled(value);
                        setState(() => _locationSharing = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.clock,
                      title: isArabic ? 'حالة الاتصال' : 'Online Status',
                      subtitle: isArabic
                          ? 'إظهار حالتك كمتصل للمستخدمين الآخرين'
                          : 'Show your online status to other users',
                      value: _showOnlineStatus,
                      onChanged: (value) {
                        SettingsService().setShowOnlineStatus(value);
                        setState(() => _showOnlineStatus = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.star,
                      title: isArabic ? 'إظهار التقييم' : 'Show Rating',
                      subtitle: isArabic
                          ? 'إظهار تقييمك للمستخدمين الآخرين'
                          : 'Show your rating to other users',
                      value: _showRating,
                      onChanged: (value) {
                        SettingsService().setShowRating(value);
                        setState(() => _showRating = value);
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    isArabic
                        ? 'هذه الإعدادات تتحكم في ما يمكن للآخرين رؤيته عنك'
                        : 'These settings control what others can see about you',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: T.onSurfaceVariant(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}
