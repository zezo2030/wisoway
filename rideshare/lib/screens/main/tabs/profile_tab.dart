import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/notification_icon_button.dart';
import '../../../widgets/common/logout_confirmation_dialog.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../home/widgets/profile_menu_item.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              T.primary(context).withValues(alpha: 0.1),
              T.surface(context),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, right: 20, left: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [NotificationIconButton()],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: T.primary(context),
                                width: 4,
                              ),
                              color: T.primary(context),
                            ),
                            child: Icon(
                              IconsaxPlusBold.profile,
                              size: 60,
                              color: T.onPrimary(context),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: AppSpacing.paddingSm,
                              decoration: BoxDecoration(
                                color: T.surface(context),
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.sm,
                              ),
                              child: Semantics(
                                label: context.l10n.editProfilePhoto,
                                button: true,
                                child: Icon(
                                  IconsaxPlusBold.camera,
                                  color: T.primary(context),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.name ?? context.l10n.defaultUserName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: user.isDriver
                                ? T.secondary(context).withValues(alpha: 0.1)
                                : T.primary(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.isDriver
                                ? context.l10n.driver
                                : context.l10n.passenger,
                            style: TextStyle(
                              color: user.isDriver
                                  ? T.secondary(context)
                                  : T.primary(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      if (user != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: user.isPhoneVerified
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    user.isPhoneVerified
                                        ? IconsaxPlusLinear.tick_circle
                                        : IconsaxPlusLinear.info_circle,
                                    size: 22,
                                    color: user.isPhoneVerified
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    user.isPhoneVerified
                                        ? context.l10n.phoneVerified
                                        : context.l10n.phoneNotVerified,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: user.isPhoneVerified
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              if (!user.isPhoneVerified)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      RouteNames.phoneAuth,
                                      arguments: {'isLinkPhone': true},
                                    ).then((_) {
                                      authProvider.loadUserProfile();
                                    });
                                  },
                                  child: Text(context.l10n.confirm),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      ProfileMenuItem(
                        icon: IconsaxPlusLinear.edit,
                        title: context.l10n.editProfileMenuItem,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.editProfile,
                          ).then((_) {
                            authProvider.loadUserProfile();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      ProfileMenuItem(
                        icon: IconsaxPlusLinear.setting_2,
                        title: context.l10n.settings,
                        onTap: () {
                          Navigator.pushNamed(context, RouteNames.settings);
                        },
                      ),
                      const SizedBox(height: 12),
                      ProfileMenuItem(
                        icon: IconsaxPlusLinear.message_question,
                        title: context.l10n.helpAndSupport,
                        onTap: () {
                          Navigator.pushNamed(context, RouteNames.support);
                        },
                      ),
                      const SizedBox(height: 12),
                      ProfileMenuItem(
                        icon: IconsaxPlusLinear.info_circle,
                        title: context.l10n.aboutApp,
                        onTap: () {
                          Navigator.pushNamed(context, RouteNames.about);
                        },
                      ),
                      const SizedBox(height: 24),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: T.error(context).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ProfileMenuItem(
                          icon: IconsaxPlusLinear.logout,
                          title: context.l10n.logout,
                          iconColor: T.error(context),
                          textColor: T.error(context),
                          onTap: () => handleLogout(context),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
