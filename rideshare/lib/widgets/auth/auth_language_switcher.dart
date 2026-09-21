import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/localization_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';

/// White AR/EN pill shown in the top corner of the auth headers.
///
/// Drawn as a globe, the active language name and a chevron, matching the
/// registration mockups. Reads and writes the locale through
/// [LocalizationService], so it needs that provider above it.
class AuthLanguageSwitcher extends StatelessWidget {
  const AuthLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();

    return Semantics(
      button: true,
      label: context.l10n.language,
      child: PopupMenuButton<String>(
        onSelected: (code) => localization.setLanguage(code),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => const [
          PopupMenuItem(value: AppConstants.langArabic, child: Text('العربية')),
          PopupMenuItem(
            value: AppConstants.langEnglish,
            child: Text('English'),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: T.outline(context)),
            boxShadow: [
              BoxShadow(
                color: T.shadow(context).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusLinear.global,
                size: 18,
                color: T.primary(context),
              ),
              const SizedBox(width: 6),
              Text(
                localization.isArabic ? 'العربية' : 'English',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
