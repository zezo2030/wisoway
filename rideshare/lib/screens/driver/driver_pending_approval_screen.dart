import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/phone_text.dart';
import '../../l10n/l10n_extensions.dart';
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
                  context.l10n.driverPendingApprovalTitle,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.driverPendingApprovalBody,
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
                        context.l10n.yourProfile,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileItem(context.l10n.name, user.name),
                      const SizedBox(height: 12),
                      _buildProfileItem(
                        context.l10n.emailOptional,
                        user.email,
                      ),
                      const SizedBox(height: 12),
                      _buildProfileItem(
                        context.l10n.phoneNumber,
                        user.phoneNumber.isNotEmpty
                            ? user.phoneNumber
                            : context.l10n.notSpecified,
                        isPhone: user.phoneNumber.isNotEmpty,
                      ),
                      const SizedBox(height: 12),
                      _buildProfileItem(context.l10n.gender, user.gender),
                      const SizedBox(height: 12),
                      _buildProfileItem(
                        context.l10n.role,
                        user.role == 'driver'
                            ? context.l10n.driver
                            : context.l10n.passenger,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                Semantics(
                  label: context.l10n.viewProfile,
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
                      child: Text(
                        context.l10n.viewProfile,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: context.l10n.signOut,
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
                    child: Text(
                      context.l10n.signOut,
                      style: const TextStyle(fontSize: 16),
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

  Widget _buildProfileItem(String label, String value, {bool isPhone = false}) {
    final valueStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: T.onSurface(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: T.onSurfaceVariant(context)),
        ),
        const SizedBox(height: 4),
        if (isPhone) PhoneText(value, style: valueStyle) else Text(value, style: valueStyle),
      ],
    );
  }
}
