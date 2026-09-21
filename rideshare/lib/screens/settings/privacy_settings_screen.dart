import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/services/settings_service.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../../widgets/settings/settings_switch_tile.dart';
import '../../l10n/l10n_extensions.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _settings = SettingsService();
  bool _loading = true;
  bool _locationSharing = true;
  bool _onlineStatus = true;
  bool _showRating = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locationSharing = await _settings.isLocationSharingEnabled();
    final onlineStatus = await _settings.isShowOnlineStatus();
    final showRating = await _settings.isShowRating();
    if (!mounted) return;
    setState(() {
      _locationSharing = locationSharing;
      _onlineStatus = onlineStatus;
      _showRating = showRating;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.privacySettings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingsSection(
                  title: context.l10n.privacyTitle,
                  children: [
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.location,
                      title: context.l10n.locationSharing,
                      subtitle: context.l10n.locationSharingSubtitle,
                      value: _locationSharing,
                      onChanged: (value) {
                        _settings.setLocationSharingEnabled(value);
                        setState(() => _locationSharing = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.wifi,
                      title: context.l10n.onlineStatus,
                      subtitle: context.l10n.onlineStatusSubtitle,
                      value: _onlineStatus,
                      onChanged: (value) {
                        _settings.setShowOnlineStatus(value);
                        setState(() => _onlineStatus = value);
                      },
                    ),
                    SettingsSwitchTile(
                      icon: IconsaxPlusBroken.star,
                      title: context.l10n.showRating,
                      subtitle: context.l10n.showRatingSubtitle,
                      value: _showRating,
                      onChanged: (value) {
                        _settings.setShowRating(value);
                        setState(() => _showRating = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.privacyInfo,
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
