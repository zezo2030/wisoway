import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../../widgets/settings/settings_switch_tile.dart';
import '../../l10n/l10n_extensions.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _settings = SettingsService();
  bool _loading = true;
  bool _trips = true;
  bool _payments = true;
  bool _messages = true;
  bool _system = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await _settings.isNotifCategoryEnabled(
      AppConstants.keyNotifTrips,
    );
    final payments = await _settings.isNotifCategoryEnabled(
      AppConstants.keyNotifPayments,
    );
    final messages = await _settings.isNotifCategoryEnabled(
      AppConstants.keyNotifMessages,
    );
    final system = await _settings.isNotifCategoryEnabled(
      AppConstants.keyNotifSystem,
    );
    if (!mounted) return;
    setState(() {
      _trips = trips;
      _payments = payments;
      _messages = messages;
      _system = system;
      _loading = false;
    });
  }

  Future<void> _setCategory(String key, bool value) async {
    await _settings.setNotifCategoryEnabled(key, value);
    if (!mounted) return;
    setState(() {
      if (key == AppConstants.keyNotifTrips) _trips = value;
      if (key == AppConstants.keyNotifPayments) _payments = value;
      if (key == AppConstants.keyNotifMessages) _messages = value;
      if (key == AppConstants.keyNotifSystem) _system = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.notificationSettingsTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: context.l10n.notificationCategories,
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.car,
                      title: context.l10n.notifTrips,
                      value: _trips,
                      onChanged: (value) =>
                          _setCategory(AppConstants.keyNotifTrips, value),
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.wallet,
                      title: context.l10n.notifPayments,
                      value: _payments,
                      onChanged: (value) =>
                          _setCategory(AppConstants.keyNotifPayments, value),
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.message,
                      title: context.l10n.notifMessages,
                      value: _messages,
                      onChanged: (value) =>
                          _setCategory(AppConstants.keyNotifMessages, value),
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.notification,
                      title: context.l10n.notifSystem,
                      value: _system,
                      onChanged: (value) =>
                          _setCategory(AppConstants.keyNotifSystem, value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.notifCustomizeInfo,
                  style: TextStyle(
                    fontSize: 13,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
    );
  }
}
