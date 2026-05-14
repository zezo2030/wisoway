import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/phone_text.dart';
import '../../../widgets/notification_icon_button.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              T.primary(context).withValues(alpha: 0.1),
              T.surface(context),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً',
                            style: TextStyle(
                              fontSize: 16,
                              color: T.onSurfaceVariant(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.name ?? 'المستخدم',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: T.onSurface(context),
                            ),
                          ),
                        ],
                      ),
                      const NotificationIconButton(),
                    ],
                  ),
                  const SizedBox(height: 32),

                  if (user != null && user.canCreateTrips) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [T.primary(context), AppColors.teal700],
                        ),
                        borderRadius: AppRadius.radiusXl,
                        boxShadow: AppShadows.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ابدأ رحلتك',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أنشئ رحلة جديدة واكسب المال',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: Semantics(
                              button: true,
                              label: 'إنشاء رحلة جديدة',
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    RouteNames.createTrip,
                                  );
                                },
                                icon: const Icon(
                                  IconsaxPlusBold.add_circle,
                                  color: AppColors.white,
                                ),
                                label: const Text(
                                  'إنشاء رحلة جديدة',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.white.withValues(
                                    alpha: 0.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (user != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: T.surface(context),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: T
                                      .primary(context)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  IconsaxPlusLinear.profile_circle,
                                  color: T.primary(context),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'معلومات المستخدم',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: T.onSurface(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow(
                            context: context,
                            icon: IconsaxPlusLinear.profile,
                            label: 'الاسم',
                            value: user.name,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            context: context,
                            icon: IconsaxPlusLinear.call,
                            label: 'رقم الهاتف',
                            value: user.phoneNumber,
                            isPhone: true,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            context: context,
                            icon: IconsaxPlusLinear.profile_2user,
                            label: 'الجنس',
                            value: user.isMale ? 'ذكر' : 'أنثى',
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            context: context,
                            icon: IconsaxPlusLinear.award,
                            label: 'الدور',
                            value: user.isDriver ? 'سائق' : 'راكب',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (user != null && user.canCreateTrips) ...[
                    Text(
                      'إحصائيات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            icon: IconsaxPlusBold.car,
                            title: 'الرحلات',
                            value: '0',
                            color: T.primary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context: context,
                            icon: IconsaxPlusBold.people,
                            title: 'الركاب',
                            value: '0',
                            color: T.secondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool isPhone = false,
  }) {
    final valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: T.onSurface(context),
    );
    return Row(
      children: [
        Icon(icon, size: 20, color: T.onSurfaceVariant(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
          ),
        ),
        if (isPhone)
          PhoneText(value, style: valueStyle)
        else
          Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: T.onSurfaceVariant(context)),
          ),
        ],
      ),
    );
  }
}
