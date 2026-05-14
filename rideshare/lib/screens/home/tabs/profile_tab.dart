import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/colors.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/notification_icon_button.dart';
import '../../../widgets/common/logout_confirmation_dialog.dart';
import '../widgets/profile_menu_item.dart';

class ProfileTab extends StatefulWidget {
  final UserModel? user;

  const ProfileTab({super.key, this.user});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _refreshing = false;

  UserModel? get user => widget.user;

  Future<void> _onRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context.read<AuthProvider>().loadUserProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث البيانات'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث البيانات: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _refreshing ? null : _onRefresh,
            icon: _refreshing
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        T.onSurface(context),
                      ),
                    ),
                  )
                : Icon(
                    IconsaxPlusLinear.refresh,
                    color: T.onSurface(context),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: NotificationIconButton(
              backgroundColor: AppColors.transparent,
              iconColor: T.onSurface(context),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: T.primary(context),
                child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user!.photoUrl!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          errorWidget: (context, url, error) => const Icon(
                            IconsaxPlusBold.profile,
                            size: 60,
                            color: AppColors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        IconsaxPlusBold.profile,
                        size: 60,
                        color: AppColors.white,
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'المستخدم',
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
                    color: user!.isDriver
                        ? T.secondary(context).withValues(alpha: 0.1)
                        : T.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user!.isDriver ? 'سائق' : 'راكب',
                    style: TextStyle(
                      color: user!.isDriver
                          ? T.secondary(context)
                          : T.primary(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (user != null && user!.isDriver) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: user!.isDriverApproved
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: user!.isDriverApproved
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            user!.isDriverApproved
                                ? IconsaxPlusBold.tick_circle
                                : IconsaxPlusBold.timer,
                            color: user!.isDriverApproved
                                ? AppColors.success
                                : AppColors.warningDark,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            user!.isDriverApproved
                                ? 'تمت الموافقة على بياناتك'
                                : 'حسابك كسائق قيد المراجعة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: user!.isDriverApproved
                                  ? AppColors.success
                                  : AppColors.warningDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user!.isDriverApproved
                            ? 'يمكنك إنشاء رحلات وإدارتها من تبويب "رحلاتي".'
                            : 'لا يمكنك إنشاء رحلات حتى تتم الموافقة على بياناتك من الإدارة. يمكنك حالياً الحجز كراكب.',
                        style: TextStyle(
                          fontSize: 13,
                          color: T.onSurfaceVariant(context),
                        ),
                      ),
                      if (!user!.isDriverApproved) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                RouteNames.driverPendingApproval,
                              );
                            },
                            icon: const Icon(
                              IconsaxPlusLinear.info_circle,
                              size: 18,
                            ),
                            label: const Text('معرفة حالة التوثيق'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warningDark,
                              side: BorderSide(color: AppColors.warningLight),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ProfileMenuItem(
                icon: IconsaxPlusLinear.edit,
                title: 'تعديل الملف الشخصي',
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.editProfile);
                },
              ),
              const SizedBox(height: 12),
              ProfileMenuItem(
                icon: IconsaxPlusLinear.setting_2,
                title: 'الإعدادات',
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.settings);
                },
              ),
              const SizedBox(height: 12),
              ProfileMenuItem(
                icon: IconsaxPlusLinear.message_question,
                title: 'المساعدة والدعم',
                onTap: () {
                  Navigator.pushNamed(context, RouteNames.support);
                },
              ),
              const SizedBox(height: 12),
              ProfileMenuItem(
                icon: IconsaxPlusLinear.info_circle,
                title: 'حول التطبيق',
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
                  title: 'تسجيل الخروج',
                  iconColor: T.error(context),
                  textColor: T.error(context),
                  onTap: () => handleLogout(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
