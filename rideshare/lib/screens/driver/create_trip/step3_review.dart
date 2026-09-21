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
///
/// Laid out to the review mockup: the route runs left-to-right across the
/// summary card rather than down it, and the facts underneath sit in one
/// divided strip so the whole trip fits on a single screen.
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

  static const double _cardGap = 12;

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
          const SizedBox(height: 18),
          _buildSummaryCard(context),
          if (_feeNoticeContent(context) case final feeNotice?) ...[
            const SizedBox(height: _cardGap),
            feeNotice,
          ],
          const SizedBox(height: _cardGap),
          _buildExtrasCard(context),
          const SizedBox(height: _cardGap),
          _buildVehicleCard(context),
          if (wizard.notes.isNotEmpty) ...[
            const SizedBox(height: _cardGap),
            _buildNotesCard(context),
          ],
          const SizedBox(height: _cardGap),
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

    return _sectionCard(
      context,
      icon: Icons.description_outlined,
      title: context.l10n.tripSummarySection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _horizontalRoute(context),
          if (wizard.stops.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${context.l10n.stopsLabel}: '
              '${wizard.stops.map((s) => s.name).join(' • ')}',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: T.outline(context), height: 1),
          const SizedBox(height: 14),
          _factStrip(context, [
            _FactData(
              icon: IconsaxPlusBroken.calendar_1,
              label: context.l10n.dateLabel,
              value: departure == null
                  ? '—'
                  : DateFormat.yMMMMEEEEd(locale).format(departure),
            ),
            _FactData(
              icon: IconsaxPlusBroken.clock,
              label: context.l10n.departureTimeLabel,
              value: departure == null
                  ? '—'
                  : DateFormat('hh:mm a', locale).format(departure),
            ),
            _FactData(
              icon: Icons.airline_seat_recline_normal_rounded,
              label: context.l10n.availableSeatsSection,
              value: context.l10n.seatsCount(wizard.availableSeatCount),
            ),
            _FactData(
              icon: IconsaxPlusBroken.wallet_1,
              label: context.l10n.pricePerSeat,
              value: price == null
                  ? '—'
                  : '${price.toStringAsFixed(2)} $currency',
            ),
          ]),
        ],
      ),
    );
  }

  /// Origin on the leading side, destination on the trailing side, joined by a
  /// dashed line with the car riding it — the mockup's route strip.
  ///
  /// Labels and values are two aligned rows sharing the same flex weights, so
  /// the connector lines up with the place names at any text scale.
  Widget _horizontalRoute(BuildContext context) {
    final labelStyle = AppTextStyles.bodySmall.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    final valueStyle = AppTextStyles.bodyLarge.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: T.onSurface(context),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                context.l10n.fromLabel,
                style: labelStyle.copyWith(color: T.success(context)),
              ),
            ),
            const Expanded(flex: 4, child: SizedBox.shrink()),
            Expanded(
              flex: 3,
              child: Text(
                context.l10n.toLabel,
                textAlign: TextAlign.end,
                style: labelStyle.copyWith(color: T.error(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                wizard.from?.name ?? '—',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
            Expanded(flex: 4, child: _routeConnector(context)),
            Expanded(
              flex: 3,
              child: Text(
                wizard.to?.name ?? '—',
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _routeConnector(BuildContext context) {
    final line = T.outlineVariant(context);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: T.success(context),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: _DashedLine(color: line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            IconsaxPlusBroken.car,
            size: 20,
            color: T.onSurfaceVariant(context),
          ),
        ),
        Expanded(child: _DashedLine(color: line)),
        Icon(Icons.location_on, size: 18, color: T.error(context)),
      ],
    );
  }

  /// The four trip facts as one divided strip, the way the mockup lines them
  /// up under the route.
  Widget _factStrip(BuildContext context, List<_FactData> facts) {
    final children = <Widget>[];
    for (var i = 0; i < facts.length; i++) {
      if (i > 0) {
        children.add(
          Container(width: 1, height: 46, color: T.outline(context)),
        );
      }
      children.add(Expanded(child: _fact(context, facts[i])));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _fact(BuildContext context, _FactData fact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(fact.icon, size: 15, color: T.primary(context)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  fact.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 11,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fact.value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: T.onSurface(context),
            ),
          ),
        ],
      ),
    );
  }

  // --- extras --------------------------------------------------------------

  Widget _buildExtrasCard(BuildContext context) {
    return _sectionCard(
      context,
      icon: Icons.more_vert_rounded,
      title: context.l10n.additionalDetailsTitle,
      child: _factStrip(context, [
        _FactData(
          icon: IconsaxPlusBroken.shield_tick,
          label: context.l10n.preventGenderMixing,
          value: wizard.preventGenderMixing
              ? context.l10n.yes
              : context.l10n.no,
        ),
        _FactData(
          icon: Icons.repeat_rounded,
          label: context.l10n.tripRecurrence,
          value: _recurrenceSummary(context),
        ),
      ]),
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
          // Details lead, photo trails — the mockup puts the car on the far
          // side of the card from its name.
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.model.isNotEmpty ? car.model : '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: T.onSurface(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _plateBadge(context, car.plateNumber),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 108,
                    height: 72,
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

  /// Number plate as it looks on the car: the country strip, then the number.
  Widget _plateBadge(BuildContext context, String plate) {
    const plateInk = Color(0xFF1B4D3E);
    final text = plate.isNotEmpty ? plate : '—';

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: plateInk, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: plateInk,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              size: 13,
              color: AppColors.white,
            ),
          ),
          const SizedBox(width: 8),
          // Flexible so a long plate ellipsises instead of pushing the badge
          // past the card on a narrow phone.
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: plateInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- notes ---------------------------------------------------------------

  Widget _buildNotesCard(BuildContext context) {
    // The driver writes free text, so each line becomes its own bullet the way
    // the mockup lists one instruction per row.
    final lines = wizard.notes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return _sectionCard(
      context,
      icon: Icons.chat_bubble_outline_rounded,
      title: context.l10n.notesForPassengers,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 7,
                    color: T.primary(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lines[i],
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 14,
                      color: T.onSurface(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- fee notice ----------------------------------------------------------

  /// The fee line for the review step. While the quote is loading, shows a
  /// neutral progress row; if it never loads, the row is omitted entirely —
  /// the backend still enforces the balance check at publish time, so this
  /// line is purely informational and must never block or misreport.
  Widget? _feeNoticeContent(BuildContext context) {
    if (isLoadingFeeQuote) {
      return _noticeCard(
        context,
        leading: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: T.primary(context),
          ),
        ),
        body: context.l10n.loading,
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

    return _noticeCard(
      context,
      leading: Icon(
        IconsaxPlusBold.wallet_1,
        size: 20,
        color: T.primary(context),
      ),
      body: context.l10n.createTripFeeNotice(
        _formatPercent(quote.percent),
        amount.toStringAsFixed(2),
        quote.currency,
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
    return _noticeCard(
      context,
      leading: Icon(
        IconsaxPlusBold.shield_tick,
        size: 20,
        color: T.primary(context),
      ),
      title: context.l10n.publishTripNoticeTitle,
      body: context.l10n.publishTripNotice,
    );
  }

  /// Muted panel with a chipped icon: the mockup's closing notice, reused by
  /// the fee line above it so the two read as one family.
  Widget _noticeCard(
    BuildContext context, {
    required Widget leading,
    required String body,
    String? title,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.outline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: T.surface(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: leading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  body,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
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
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: T.primary(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontSize: 16,
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

/// One labelled fact in a [Step3Review] strip.
class _FactData {
  const _FactData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// The dashed rule the route strip is drawn on.
class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: CustomPaint(painter: _DashedLinePainter(color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  static const double _dash = 4;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      final end = (x + _dash).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
