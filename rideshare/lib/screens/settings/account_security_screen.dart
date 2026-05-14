import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/services/localization_service.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/phone_text.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/settings/settings_section.dart';

class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizationService = context.watch<LocalizationService>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.userModel;
    final isArabic = localizationService.isArabic;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'الحساب والأمان' : 'Account & Security'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'الحساب والأمان' : 'Account & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: isArabic ? 'معلومات الحساب' : 'Account Details',
            children: [
              _InfoRow(
                icon: IconsaxPlusBroken.direct_right,
                label: isArabic ? 'البريد الإلكتروني' : 'Email',
                value: user.email,
              ),
              _InfoRow(
                icon: IconsaxPlusBroken.call,
                label: isArabic ? 'رقم الهاتف' : 'Phone',
                value: user.phoneNumber,
                isPhone: true,
                trailing: user.isPhoneVerified
                    ? null
                    : TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, RouteNames.phoneAuth);
                        },
                        child: Text(isArabic ? 'ربط' : 'Link'),
                      ),
              ),
              _InfoRow(
                icon: IconsaxPlusBroken.user_tag,
                label: isArabic ? 'نوع الحساب' : 'Account Type',
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
                        ? (isArabic ? 'سائق' : 'Driver')
                        : (isArabic ? 'راكب' : 'Passenger'),
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
            title: isArabic ? 'حالة التوثيق' : 'Verification Status',
            children: [
              _VerificationRow(
                label: isArabic ? 'البريد الإلكتروني' : 'Email',
                isVerified: user.isEmailVerified,
              ),
              _VerificationRow(
                label: isArabic ? 'رقم الهاتف' : 'Phone',
                isVerified: user.isPhoneVerified,
              ),
              if (user.isDriver)
                _VerificationRow(
                  label: isArabic ? 'موافقة السائق' : 'Driver Approval',
                  isVerified: user.isDriverApproved,
                  pending: !user.isDriverApproved,
                ),
            ],
          ),
          SettingsSection(
            title: isArabic ? 'الأجهزة الموثوقة' : 'Trusted Devices',
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                  IconsaxPlusBroken.mobile,
                  color: T.primary(context),
                ),
                title: Text(isArabic ? 'إدارة الأجهزة' : 'Manage Devices'),
                subtitle: Text(
                  isArabic
                      ? 'عرض وإلغاء الأجهزة المرتبطة بحسابك'
                      : 'View and revoke devices linked to your account',
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
    final localizationService = context.watch<LocalizationService>();
    final isArabic = localizationService.isArabic;

    Color badgeColor;
    String badgeText;
    String icon;

    if (pending) {
      badgeColor = AppColors.warning;
      badgeText = isArabic ? 'قيد المراجعة' : 'Pending';
      icon = '⏳';
    } else if (isVerified) {
      badgeColor = AppColors.success;
      badgeText = isArabic ? 'موثق' : 'Verified';
      icon = '✅';
    } else {
      badgeColor = AppColors.error;
      badgeText = isArabic ? 'غير موثق' : 'Not Verified';
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
