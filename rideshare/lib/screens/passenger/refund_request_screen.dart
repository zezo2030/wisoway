// T175 — RefundRequestScreen
//
// Lets a passenger request a refund for a booking.
// Receives named route arguments map:
//   { 'bookingId': String (required), 'tripRef': String? (optional display text) }
//
// API: POST /refund-requests  → 201 { whatsappLink, refundRequest }
// On success, opens the returned WhatsApp deep-link directly.

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';

class RefundRequestScreen extends StatefulWidget {
  final String bookingId;
  final String? tripRef;

  const RefundRequestScreen({
    super.key,
    required this.bookingId,
    this.tripRef,
  });

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'bookingId': widget.bookingId,
        'reason': _reasonController.text.trim(),
      };

      final data = await ApiClient().post('/refund-requests', data: body);

      // Backend returns { whatsappLink, refundRequest }
      final whatsappLink = data['whatsappLink'] as String?;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'تم تسجيل طلب الاسترداد. سيتم تحويلك إلى WhatsApp لاستكمال الإجراء.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pop(context, true);

        // Open WhatsApp deep-link after a short delay so the pop animates
        if (whatsappLink != null) {
          await Future.delayed(const Duration(milliseconds: 400));
          final uri = Uri.parse(whatsappLink);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorSurface.showFailure(context, ApiClient.mapError(e));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
              AppColors.warningDark.withValues(alpha: 0.07),
              T.background(context),
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // ── App bar ──────────────────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(IconsaxPlusLinear.arrow_right_2),
                      style: IconButton.styleFrom(
                        backgroundColor: T.surface(context),
                        foregroundColor: T.onSurface(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'طلب استرداد المبلغ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: T.onSurface(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Hero card ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: T.surface(context),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: T.shadow(context).withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.warningDark.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          IconsaxPlusBold.money_recive,
                          color: AppColors.warningDark,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'استرداد رسوم الحجز',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: T.onSurface(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.tripRef != null
                                  ? 'الرحلة: ${widget.tripRef}'
                                  : 'سيتواصل معك فريقنا عبر WhatsApp لإتمام الإجراء.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: T.onSurfaceVariant(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Reason ───────────────────────────────────────────────
                Text(
                  'سبب طلب الاسترداد',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        'اشرح سبب طلبك لاسترداد المبلغ بإيجاز…',
                    filled: true,
                    fillColor: T.surface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: T.outline(context).withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: T.outline(context).withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.warningDark,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى كتابة سبب الطلب';
                    }
                    if (v.trim().length < 10) {
                      return 'السبب قصير جداً (10 أحرف على الأقل)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Info note ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        IconsaxPlusLinear.info_circle,
                        size: 18,
                        color: AppColors.warningDark,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'بعد الإرسال، ستُفتح محادثة WhatsApp مع فريق الدعم لإتمام إجراء الاسترداد.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: AppColors.warningDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Submit ───────────────────────────────────────────────
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warningDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إرسال الطلب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
