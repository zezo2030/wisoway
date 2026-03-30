import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../core/constants/route_names.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/colors.dart';

Future<bool?> showLogoutConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
      title: Text(
        'تسجيل الخروج',
        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
      ),
      content: Text(
        'هل أنت متأكد من تسجيل الخروج؟',
        style: GoogleFonts.tajawal(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('إلغاء', style: GoogleFonts.tajawal()),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: T.error(context)),
          child: Text(
            'تسجيل الخروج',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.w600),
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
