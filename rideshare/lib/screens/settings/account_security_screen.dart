import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/phone_text.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/settings/settings_section.dart';
import '../../l10n/l10n_extensions.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.accountSecurity),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountSecurity),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: context.l10n.accountDetails,
            children: [
              _InfoRow(
                icon: IconsaxPlusBroken.direct_right,
                label: context.l10n.emailLabel,
                value: user.email,
              ),
              _InfoRow(
                icon: IconsaxPlusBroken.call,
                label: context.l10n.phoneLabel,
                value: user.phoneNumber,
                isPhone: true,
                trailing: user.isPhoneVerified
                    ? null
                    : TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, RouteNames.phoneAuth);
                        },
                        child: Text(context.l10n.linkPhone),
                      ),
              ),
              _InfoRow(
                icon: IconsaxPlusBroken.user_tag,
                label: context.l10n.accountType,
                value: '',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.isDriver
                        ? T.primary(context).withValues(alpha: 0.1)
                        : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.isDriver
                        ? context.l10n.roleDriver
                        : context.l10n.rolePassenger,
                    style: TextStyle(
                      color: user.isDriver
                          ? T.primary(context)
                          : AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: context.l10n.verificationStatus,
            children: [
              _VerificationRow(
                label: context.l10n.emailLabel,
                isVerified: user.isEmailVerified,
              ),
              _VerificationRow(
                label: context.l10n.phoneLabel,
                isVerified: user.isPhoneVerified,
              ),
              if (user.isDriver)
                _VerificationRow(
                  label: context.l10n.driverApproval,
                  isVerified: user.isDriverApproved,
                  pending: !user.isDriverApproved,
                ),
            ],
          ),
          SettingsSection(
            title: context.l10n.devicesScreenTitle,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                  IconsaxPlusBroken.mobile,
                  color: T.primary(context),
                ),
                title: Text(context.l10n.manageDevices),
                subtitle: Text(
                  context.l10n.manageDevicesSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pushNamed(
                  context,
                  RouteNames.accountSecurityDevices,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool isPhone;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.isPhone = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: T.onSurface(context));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: T.onSurfaceVariant(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 2),
                if (isPhone && value.isNotEmpty)
                  PhoneText(value, style: valueStyle)
                else
                  Text(value.isNotEmpty ? value : '-', style: valueStyle),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _VerificationRow extends StatelessWidget {
  final String label;
  final bool isVerified;
  final bool pending;

  const _VerificationRow({
    required this.label,
    required this.isVerified,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String badgeText;
    String icon;

    if (pending) {
      badgeColor = AppColors.warning;
      badgeText = context.l10n.pending;
      icon = '⏳';
    } else if (isVerified) {
      badgeColor = AppColors.success;
      badgeText = context.l10n.verified;
      icon = '✅';
    } else {
      badgeColor = AppColors.error;
      badgeText = context.l10n.notVerified;
      icon = '❌';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: T.onSurface(context)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
