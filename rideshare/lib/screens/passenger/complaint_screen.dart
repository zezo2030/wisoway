// T173 — ComplaintScreen
//
// Lets a passenger (or driver) submit a complaint.
// Accepts optional named arguments:
//   - againstUserId (String)  — the user being complained about
//   - tripId        (String)  — the associated trip
//
// API: POST /complaints   → 201 on success

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';

// Must mirror ComplaintCategory const-enum in complaint.entity.ts
const _kCategoryCodes = [
  'SAFETY',
  'PAYMENT',
  'VEHICLE_CONDITION',
  'DRIVER_BEHAVIOR',
  'APP_ISSUE',
  'OTHER',
];

String _categoryLabel(BuildContext context, String code) {
  switch (code) {
    case 'SAFETY':
      return context.l10n.complaintCategorySafety;
    case 'PAYMENT':
      return context.l10n.complaintCategoryPayment;
    case 'VEHICLE_CONDITION':
      return context.l10n.complaintCategoryVehicleCondition;
    case 'DRIVER_BEHAVIOR':
      return context.l10n.complaintCategoryDriverBehavior;
    case 'APP_ISSUE':
      return context.l10n.complaintCategoryAppIssue;
    default:
      return context.l10n.complaintCategoryOther;
  }
}

class ComplaintScreen extends StatefulWidget {
  final String? againstUserId;
  final String? tripId;

  const ComplaintScreen({
    super.key,
    this.againstUserId,
    this.tripId,
  });

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  String _category = _kCategoryCodes.first;
  bool _submitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'category': _category,
        'description': _descController.text.trim(),
        if (widget.againstUserId != null) 'againstUserId': widget.againstUserId,
        if (widget.tripId != null) 'tripId': widget.tripId,
      };

      await ApiClient().post('/complaints', data: body);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.complaintSubmittedSuccessMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
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
              T.primary(context).withValues(alpha: 0.07),
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
                        context.l10n.complaintScreenTitle,
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
                _HeroCard(
                  icon: IconsaxPlusBold.message_question,
                  title: context.l10n.complaintHeroTitle,
                  subtitle: context.l10n.complaintHeroSubtitle,
                ),
                const SizedBox(height: 24),

                // ── Category picker ──────────────────────────────────────
                _SectionLabel(context.l10n.complaintTypeLabel),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: T.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: T.outline(context).withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: _kCategoryCodes
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(_categoryLabel(context, code)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── Description ──────────────────────────────────────────
                _SectionLabel(context.l10n.complaintProblemDescriptionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descController,
                  maxLines: 5,
                  maxLength: 1000,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: context.l10n.complaintDescriptionHint,
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
                        color: T.primary(context),
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.l10n.complaintDescriptionRequired;
                    }
                    if (v.trim().length < 10) {
                      return context.l10n.complaintDescriptionTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // ── Submit ───────────────────────────────────────────────
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
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
                      : Text(
                          context.l10n.complaintSubmitButton,
                          style: const TextStyle(
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

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: T.onSurfaceVariant(context),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
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
            color: T.shadow(context).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: T.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: T.primary(context), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: T.onSurface(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
    );
  }
}
