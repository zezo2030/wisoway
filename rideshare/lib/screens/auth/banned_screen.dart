// T174 — BannedScreen
//
// Full-screen gate rendered when the user's account is banned (403 ACCOUNT_BANNED).
// Receives optional arguments map:
//   { 'banReason': String?, 'supportWhatsApp': String? }
//
// The AuthInterceptor clears tokens and navigates here via pushNamedAndRemoveUntil.
// On "Contact Support" the screen opens WhatsApp with a prefilled message.

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/colors.dart';
import '../../core/constants/support_constants.dart';
import '../../l10n/l10n_extensions.dart';

class BannedScreen extends StatefulWidget {
  const BannedScreen({super.key});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  String? _banReason;
  String? _supportWhatsApp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _banReason = args?['banReason'] as String?;
    _supportWhatsApp = args?['supportWhatsApp'] as String?;
  }

  String get _whatsAppNumber {
    // Prefer number from ban response, fall back to support constant
    final raw = _supportWhatsApp ?? SupportConstants.supportPhone;
    // Strip leading '+' for wa.me URL
    return raw.replaceAll('+', '').replaceAll(' ', '');
  }

  Future<void> _openWhatsApp() async {
    final prefill = Uri.encodeComponent(
      context.l10n.bannedWhatsAppPrefill,
    );
    final uri = Uri.parse('https://wa.me/$_whatsAppNumber?text=$prefill');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotOpenWhatsApp),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchConfigAndOpen() async {
    // If we already have the number, open immediately
    if (_supportWhatsApp != null) {
      await _openWhatsApp();
      return;
    }
    // Otherwise try to fetch from /support/config (best-effort)
    try {
      final data = await ApiClient().get('/support/config');
      if (mounted) {
        setState(() {
          _supportWhatsApp = data['whatsappE164'] as String?;
        });
      }
    } catch (_) {
      // fall back to constant
    }
    await _openWhatsApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.errorDark.withValues(alpha: 0.08),
              T.background(context),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // ── Icon ─────────────────────────────────────────────────
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.errorDark.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconsaxPlusBold.shield_slash,
                    size: 44,
                    color: AppColors.errorDark,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────
                Text(
                  context.l10n.accountBannedTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Reason ────────────────────────────────────────────────
                Text(
                  _banReason?.isNotEmpty == true
                      ? _banReason!
                      : context.l10n.accountBannedNoReason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.65,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Contact Support ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _fetchConfigAndOpen,
                    icon: const Icon(IconsaxPlusBold.message, size: 20),
                    label: Text(
                      context.l10n.contactSupportViaWhatsApp,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── Footer ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'VisionWay © ${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: T.onSurfaceVariant(context).withValues(alpha: 0.5),
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
}
