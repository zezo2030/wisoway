import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import 'legal_content.dart';

/// Terms of Use or Privacy Policy, in the app's current language.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  static Route<void> route(LegalDocumentKind kind) =>
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(kind: kind));

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final doc = legalContent(kind, languageCode);
    final updatedLabel = languageCode == 'en' ? 'Last updated' : 'آخر تحديث';

    return Scaffold(
      backgroundColor: T.surface(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: T.surface(context),
        foregroundColor: T.onSurface(context),
        title: Text(
          doc.title,
          style: AppTextStyles.titleMedium.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '$updatedLabel: $kLegalLastUpdated',
              style: AppTextStyles.bodySmall.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(doc.intro, style: _body(context)),
            for (final section in doc.sections) ...[
              const SizedBox(height: 22),
              Text(
                section.title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 8),
              for (final paragraph in section.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(paragraph, style: _body(context)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle _body(BuildContext context) => AppTextStyles.bodyMedium.copyWith(
    height: 1.7,
    color: T.onSurface(context),
  );
}
