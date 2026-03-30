import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

class DriverPendingApprovalScreen extends StatefulWidget {
  const DriverPendingApprovalScreen({super.key});

  @override
  State<DriverPendingApprovalScreen> createState() =>
      _DriverPendingApprovalScreenState();
}

class _DriverPendingApprovalScreenState
    extends State<DriverPendingApprovalScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: T.surface(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: T.primary(context).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconsaxPlusBold.timer,
                    size: 100,
                    color: T.primary(context),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'حسابك قيد المراجعة',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'نحن نقوم بمراجعة حسابك. سيتم إشعارك عند الموافقة.',
                  style: TextStyle(
                    fontSize: 16,
                    color: T.onSurfaceVariant(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: T.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: T.onSurface(context).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملفك الشخصي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileItem('الاسم', user.name),
                      const SizedBox(height: 12),
                      _buildProfileItem('البريد الإلكتروني', user.email),
                      const SizedBox(height: 12),
                      _buildProfileItem(
                        'رقم الهاتف',
                        user.phoneNumber ?? 'غير محدد',
                      ),
                      const SizedBox(height: 12),
                      _buildProfileItem('الجنس', user.gender),
                      const SizedBox(height: 12),
                      _buildProfileItem(
                        'الدور',
                        user.role == 'driver' ? 'سائق' : 'راكب',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                Semantics(
                  label: 'عرض الملف الشخصي',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, RouteNames.profile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: T.primary(context),
                        foregroundColor: T.onPrimary(context),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'عرض الملف الشخصي',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'تسجيل خروج',
                  button: true,
                  child: OutlinedButton(
                    onPressed: () async {
                      await authProvider.signOut();
                      if (mounted) {
                        Navigator.pushReplacementNamed(
                          context,
                          RouteNames.signIn,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.onSurfaceVariant(context),
                      side: BorderSide(
                        color: T
                            .onSurfaceVariant(context)
                            .withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تسجيل خروج',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: T.onSurface(context),
          ),
        ),
      ],
    );
  }
}
