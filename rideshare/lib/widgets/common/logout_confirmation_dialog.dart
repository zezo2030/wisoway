import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../l10n/l10n_extensions.dart';

Future<bool?> showLogoutConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      title: Text(
        context.l10n.logoutConfirmTitle,
        style: AppTextStyles.titleMediumWithContext(context),
      ),
      content: Text(
        context.l10n.logoutConfirmMessage,
        style: AppTextStyles.bodyMediumWithContext(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            context.l10n.cancel,
            style: AppTextStyles.bodyMediumWithContext(context),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: T.error(context)),
          child: Text(
            context.l10n.logoutButton,
            style: AppTextStyles.labelLargeWithContext(context),
          ),
        ),
      ],
    ),
  );
}

Future<void> handleLogout(BuildContext context) async {
  final confirm = await showLogoutConfirmationDialog(context);
  if (confirm == true && context.mounted) {
    context.read<AuthBloc>().add(const AuthSignOut());
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, RouteNames.signIn);
    }
  }
}
