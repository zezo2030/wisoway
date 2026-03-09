import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../providers/auth_provider.dart';
import '../../../bloc/auth/auth_bloc.dart';
import '../../../bloc/auth/auth_event.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../widgets/notification_icon_button.dart';

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
            colors: [AppColors.primary.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Notifications Icon at top
                Padding(
                  padding: const EdgeInsets.only(top: 16, right: 20, left: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [NotificationIconButton()],
                  ),
                ),
                // Profile Header
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
                                color: AppColors.primary,
                                width: 4,
                              ),
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                              ),
                            ),
                            child: const Icon(
                              IconsaxPlusBold.profile,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                IconsaxPlusBold.camera,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.name ?? 'المستخدم',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
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
                                ? AppColors.secondary.withOpacity(0.1)
                                : AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.isDriver ? 'سائق' : 'راكب',
                            style: TextStyle(
                              color: user.isDriver
                                  ? AppColors.secondary
                                  : AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      // Phone verification status
                      if (user != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: user.isPhoneVerified
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.warning.withOpacity(0.1),
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
                                        ? 'رقم الهاتف مؤكد'
                                        : 'رقم الهاتف غير مؤكد',
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
                                  child: const Text('تأكيد'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Menu Items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: IconsaxPlusLinear.edit,
                        title: 'تعديل الملف الشخصي',
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
                      _buildMenuItem(
                        icon: IconsaxPlusLinear.setting_2,
                        title: 'الإعدادات',
                        onTap: () {
                          // TODO: Navigate to settings
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: IconsaxPlusLinear.message_question,
                        title: 'المساعدة والدعم',
                        onTap: () {
                          // TODO: Navigate to help
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        icon: IconsaxPlusLinear.info_circle,
                        title: 'حول التطبيق',
                        onTap: () {
                          // TODO: Show about dialog
                        },
                      ),
                      const SizedBox(height: 24),

                      // Logout Button
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: _buildMenuItem(
                          icon: IconsaxPlusLinear.logout,
                          title: 'تسجيل الخروج',
                          iconColor: AppColors.error,
                          textColor: AppColors.error,
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text('تسجيل الخروج'),
                                content: const Text(
                                  'هل أنت متأكد من تسجيل الخروج؟',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                    ),
                                    child: const Text('تسجيل الخروج'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              context.read<AuthBloc>().add(const AuthSignOut());
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  RouteNames.signIn,
                                );
                              }
                            }
                          },
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              IconsaxPlusLinear.arrow_left_2,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
