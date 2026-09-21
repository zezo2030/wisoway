import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/trip_fee_quote.dart';
import '../../../models/vehicle_model.dart';
import 'create_trip_stepper.dart';
import 'create_trip_wizard_state.dart';
import 'step2_details.dart' show weekdayLabel;

/// Wizard step 3 — read-only recap of everything the driver entered plus the
/// publish notice. Publishing itself is triggered from the shell footer.
class Step3Review extends StatelessWidget {
  const Step3Review({
    super.key,
    required this.wizard,
    required this.vehicle,
    required this.currency,
    this.feeQuote,
    this.isLoadingFeeQuote = false,
  });

  final CreateTripWizardState wizard;
  final VehicleModel? vehicle;
  final String currency;

  /// Fetched once by the parent screen when the review step is reached.
  /// Null while unavailable (loading, or the request failed) — the fee line
  /// stays neutral rather than blocking publish or showing a wrong number.
  final TripFeeQuote? feeQuote;
  final bool isLoadingFeeQuote;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreateTripStepHeader(
            title: context.l10n.reviewTripTitle,
            subtitle: context.l10n.reviewTripSubtitle,
          ),
          const SizedBox(height: 20),
          _buildSummaryCard(context),
          if (_feeNoticeContent(context) case final feeNotice?) ...[
            const SizedBox(height: 16),
            feeNotice,
          ],
          const SizedBox(height: 16),
          _buildExtrasCard(context),
          const SizedBox(height: 16),
          _buildVehicleCard(context),
          if (wizard.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(context),
          ],
          const SizedBox(height: 16),
          _buildPublishNotice(context),
        ],
      ),
    );
  }

  // --- trip summary --------------------------------------------------------

  Widget _buildSummaryCard(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final departure = wizard.departureTime;
    final price = wizard.price;

    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  IconsaxPlusBroken.routing,
                  size: 20,
                  color: T.primary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.tripSummaryTitle,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _verticalRoute(context),
          if (wizard.stops.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${context.l10n.stopsLabel}: '
              '${wizard.stops.map((s) => s.name).join(' • ')}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: T.outline(context), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _fact(
                  context,
                  icon: IconsaxPlusBroken.calendar_1,
                  label: context.l10n.dateLabel,
                  value: departure == null
                      ? '—'
                      : DateFormat.yMMMMEEEEd(locale).format(departure),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _fact(
                  context,
                  icon: IconsaxPlusBroken.clock,
                  label: context.l10n.departureTimeLabel,
                  value: departure == null
                      ? '—'
                      : DateFormat('hh:mm a', locale).format(departure),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _fact(
                  context,
                  icon: IconsaxPlusBroken.profile_2user,
                  label: context.l10n.availableSeatsSection,
                  value: context.l10n.seatsCount(wizard.availableSeatCount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _fact(
                  context,
                  icon: IconsaxPlusBroken.wallet_1,
                  label: context.l10n.pricePerSeat,
                  value: price == null
                      ? '—'
                      : '${price.toStringAsFixed(2)} $currency',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalRoute(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: T.success(context),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: T.outlineVariant(context),
            ),
            Icon(IconsaxPlusBroken.car, size: 18, color: T.primary(context)),
            Container(
              width: 2,
              height: 36,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: T.outlineVariant(context),
            ),
            Icon(Icons.location_on, size: 18, color: T.error(context)),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.fromLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: T.success(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                wizard.from?.name ?? '—',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                context.l10n.toLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: T.error(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                wizard.to?.name ?? '—',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fact(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: T.primary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 12,
                  color: T.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- extras --------------------------------------------------------------

  Widget _buildExtrasCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.more_horiz_rounded,
      title: context.l10n.additionalDetailsTitle,
      child: Column(
        children: [
          _row(
            context,
            icon: Icons.repeat_rounded,
            label: context.l10n.tripRecurrence,
            value: _recurrenceSummary(context),
          ),
          const SizedBox(height: 12),
          _row(
            context,
            icon: IconsaxPlusBroken.shield_tick,
            label: context.l10n.preventGenderMixing,
            value: wizard.preventGenderMixing
                ? context.l10n.yes
                : context.l10n.no,
          ),
        ],
      ),
    );
  }

  String _recurrenceSummary(BuildContext context) {
    if (!wizard.enableRecurrence) return context.l10n.recurrenceStateDisabled;
    final buffer = StringBuffer(
      wizard.recurrenceFrequency == 'daily'
          ? context.l10n.recurrenceDaily
          : context.l10n.recurrenceWeekly,
    );
    if (wizard.recurrenceFrequency == 'weekly' &&
        wizard.selectedWeekdays.isNotEmpty) {
      final days = CreateTripWizardState.weekdayKeys
          .where(wizard.selectedWeekdays.contains)
          .map((k) => weekdayLabel(context, k))
          .join(' • ');
      buffer.write(' — $days');
    }
    if (wizard.recurrenceUntil != null) {
      buffer.write(
        ' — ${DateFormat('yyyy-MM-dd').format(wizard.recurrenceUntil!)}',
      );
    }
    return buffer.toString();
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: T.primary(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: T.onSurface(context),
            ),
          ),
        ),
      ],
    );
  }

  // --- vehicle -------------------------------------------------------------

  Widget _buildVehicleCard(BuildContext context) {
    final car = vehicle;
    final imageUrl = car?.carImageUrl;

    return _sectionCard(
      context,
      icon: IconsaxPlusBroken.car,
      title: context.l10n.vehicleLabel,
      child: car == null
          ? Text(
              context.l10n.noVehicleRegistered,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 110,
                    height: 78,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _vehicleFallback(context),
                          )
                        : _vehicleFallback(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.model.isNotEmpty ? car.model : '—',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _plateBadge(context, car.plateNumber),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _vehicleFallback(BuildContext context) {
    return ColoredBox(
      color: T.surfaceVariant(context),
      child: Center(
        child: Icon(
          IconsaxPlusBroken.car,
          size: 32,
          color: T.onSurfaceVariant(context),
        ),
      ),
    );
  }

  Widget _plateBadge(BuildContext context, String plate) {
    final text = plate.isNotEmpty ? plate : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1B4D3E), width: 1.4),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelLarge.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: const Color(0xFF1B4D3E),
        ),
      ),
    );
  }

  // --- notes ---------------------------------------------------------------

  Widget _buildNotesCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.chat_bubble_outline_rounded,
      title: context.l10n.notesForPassengers,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(IconsaxPlusBroken.message, size: 18, color: T.primary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              wizard.notes,
              style: AppTextStyles.bodyLarge.copyWith(
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- fee notice ------------------------------------------------------------

  /// The fee line for the review step. While the quote is loading, shows a
  /// neutral progress row; if it never loads, the row is omitted entirely —
  /// the backend still enforces the balance check at publish time, so this
  /// line is purely informational and must never block or misreport.
  Widget? _feeNoticeContent(BuildContext context) {
    const feeBg = Color(0xFFE8F4FC);
    const feeBorder = Color(0xFFB6D9F0);
    const feeIcon = Color(0xFF2B6CB0);

    Widget container(Widget child) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: feeBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: feeBorder),
        ),
        child: child,
      );
    }

    if (isLoadingFeeQuote) {
      return container(
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: feeIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.loading,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: T.onSurface(context),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final quote = feeQuote;
    final price = wizard.price;
    if (quote == null || price == null) return null;

    // Recomputed from the current price/seat count rather than trusting the
    // quote's own `amount` verbatim, in case those values changed after the
    // quote was fetched. `percent` always comes from the API — never a
    // literal (the deleted invoice dialogs both hardcoded '5%').
    final amount = price * wizard.availableSeatCount * quote.percent / 100;

    return container(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(IconsaxPlusBold.wallet_1, color: feeIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.createTripFeeNotice(
                _formatPercent(quote.percent),
                amount.toStringAsFixed(2),
                quote.currency,
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPercent(double percent) {
    return percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
  }

  // --- publish notice ------------------------------------------------------

  Widget _buildPublishNotice(BuildContext context) {
    const infoBlue = Color(0xFFE8F4FC);
    const infoBlueBorder = Color(0xFFB6D9F0);
    const infoIcon = Color(0xFF2B6CB0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: infoBlueBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(IconsaxPlusBold.shield_tick, color: infoIcon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.publishTripNotice,
              style: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- shared --------------------------------------------------------------

  Widget _sectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: T.primary(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
