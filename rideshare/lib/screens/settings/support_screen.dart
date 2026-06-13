import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/support_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/phone_text.dart';
import '../../l10n/l10n_extensions.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _whatsAppE164;

  @override
  void initState() {
    super.initState();
    _fetchWhatsAppConfig();
  }

  Future<void> _fetchWhatsAppConfig() async {
    try {
      final data = await ApiClient().get('/support/config');
      if (mounted) {
        setState(() {
          _whatsAppE164 = data['whatsappE164'] as String?;
        });
      }
    } catch (_) {
      // Non-critical — fall back to constant
    }
  }

  String get _whatsAppNumber {
    final raw = _whatsAppE164 ?? SupportConstants.supportPhone;
    return raw.replaceAll('+', '').replaceAll(' ', '');
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final phone = _whatsAppNumber;
    if (phone.isEmpty) {
      if (context.mounted) {
        _showMessage(context, context.l10n.supportNumberUnavailable);
      }
      return;
    }

    final prefillText = context.l10n.supportWhatsAppPrefill;

    // Try the wa.me HTTPS link first (works whether or not WhatsApp is
    // installed — falls back to the browser). If that fails, try the
    // native whatsapp:// scheme as a backup.
    final waMeUri = Uri.https(
      'wa.me',
      '/$phone',
      {'text': prefillText},
    );
    final deepLinkUri = Uri.parse(
      'whatsapp://send?phone=$phone'
      '&text=${Uri.encodeQueryComponent(prefillText)}',
    );

    for (final uri in [waMeUri, deepLinkUri]) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {
        // try the next URI
      }
    }

    if (context.mounted) {
      _showMessage(context, context.l10n.cannotOpenWhatsApp);
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SupportConstants.supportEmail,
      queryParameters: {'subject': SupportConstants.supportSubject},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (context.mounted) {
      _showMessage(context, context.l10n.cannotOpenEmailApp);
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(text: SupportConstants.supportEmail),
    );
    if (context.mounted) {
      _showMessage(context, context.l10n.supportEmailCopied);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              T.primary(context).withValues(alpha: 0.08),
              T.background(context),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _SupportAppBar(
                title: context.l10n.supportScreenTitle,
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 20),
              _SupportHero(
                icon: IconsaxPlusBold.message_question,
                title: context.l10n.supportHeroTitle,
                subtitle: context.l10n.supportHeroSubtitle,
              ),
              const SizedBox(height: 20),
              _ContactCard(
                icon: IconsaxPlusBold.sms,
                accentColor: T.primary(context),
                title: context.l10n.supportContactEmailTitle,
                value: SupportConstants.supportEmail,
                description: context.l10n.supportContactEmailDescription,
                primaryActionLabel: context.l10n.supportSendEmail,
                secondaryActionLabel: context.l10n.supportCopyEmail,
                onPrimaryAction: () => _launchEmail(context),
                onSecondaryAction: () => _copyEmail(context),
              ),
              const SizedBox(height: 16),
              _ContactCard(
                icon: IconsaxPlusBold.message,
                accentColor: const Color(0xFF25D366),
                title: context.l10n.supportContactWhatsAppTitle,
                value: SupportConstants.supportPhoneDisplay,
                isPhone: true,
                description: context.l10n.supportContactWhatsAppDescription,
                primaryActionLabel: context.l10n.supportWhatsAppButton,
                onPrimaryAction: () => _launchWhatsApp(context),
              ),
              const SizedBox(height: 20),
              _InfoPanel(
                title: context.l10n.supportHowWeHelpTitle,
                items: [
                  context.l10n.supportHelpItemLogin,
                  context.l10n.supportHelpItemBookings,
                  context.l10n.supportHelpItemTechnical,
                ],
              ),
              const SizedBox(height: 16),
              _InfoPanel(
                title: context.l10n.supportQuickTipTitle,
                items: [
                  context.l10n.supportTipIncludeContact,
                  context.l10n.supportTipDescribeProblem,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportAppBar extends StatelessWidget {
  const _SupportAppBar({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(IconsaxPlusLinear.arrow_right_2),
          style: IconButton.styleFrom(
            backgroundColor: T.surface(context),
            foregroundColor: T.onSurface(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: T.primary(context), size: 28),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.value,
    required this.description,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isPhone = false,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String value;
  final String description;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isPhone)
                      PhoneText(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      )
                    else
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: T.onSurfaceVariant(context),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onPrimaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(primaryActionLabel),
                ),
              ),
              if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondaryAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.onSurface(context),
                      side: BorderSide(
                        color: T.outline(context).withValues(alpha: 0.6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(secondaryActionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: T.primary(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
