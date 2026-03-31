import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/services/localization_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../../widgets/settings/settings_switch_tile.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _trips = false;
  bool _payments = false;
  bool _messages = false;
  bool _system = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final settings = SettingsService();
    _trips = await settings.isNotifCategoryEnabled(AppConstants.keyNotifTrips);
    _payments = await settings.isNotifCategoryEnabled(
      AppConstants.keyNotifPayments,
    );
    _messages = await settings.isNotifCategoryEnabled(
      AppConstants.keyNotifMessages,
    );
    _system = await settings.isNotifCategoryEnabled(
      AppConstants.keyNotifSystem,
    );
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = context.watch<LocalizationService>();
    final isArabic = localizationService.isArabic;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إعدادات الإشعارات' : 'Notification Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: isArabic
                      ? 'فئات الإشعارات'
                      : 'Notification Categories',
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.map,
                      title: isArabic ? 'الرحلات' : 'Trips',
                      subtitle: isArabic
                          ? 'إشعارات حالة الرحلة والتحديثات'
                          : 'Ride status updates and notifications',
                      value: _trips,
                      onChanged: (value) {
                        SettingsService().setNotifCategoryEnabled(
                          AppConstants.keyNotifTrips,
                          value,
                        );
                        setState(() => _trips = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.wallet_money,
                      title: isArabic ? 'المدفوعات' : 'Payments',
                      subtitle: isArabic
                          ? 'إشعارات المعاملات والفواتير'
                          : 'Transaction and invoice notifications',
                      value: _payments,
                      onChanged: (value) {
                        SettingsService().setNotifCategoryEnabled(
                          AppConstants.keyNotifPayments,
                          value,
                        );
                        setState(() => _payments = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.message,
                      title: isArabic ? 'الرسائل' : 'Messages',
                      subtitle: isArabic
                          ? 'إشعارات الرسائل والمحادثات'
                          : 'Chat and message notifications',
                      value: _messages,
                      onChanged: (value) {
                        SettingsService().setNotifCategoryEnabled(
                          AppConstants.keyNotifMessages,
                          value,
                        );
                        setState(() => _messages = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.info_circle,
                      title: isArabic ? 'النظام' : 'System',
                      subtitle: isArabic
                          ? 'إشعارات التحديثات والصيانة'
                          : 'App updates and maintenance notifications',
                      value: _system,
                      onChanged: (value) {
                        SettingsService().setNotifCategoryEnabled(
                          AppConstants.keyNotifSystem,
                          value,
                        );
                        setState(() => _system = value);
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
                        ? 'يمكنك تخصيص الإشعارات التي تريد استقبالها'
                        : 'You can customize which notifications you receive',
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
