import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/trip_price_suggestion.dart';
import '../../../utils/western_digits.dart';
import '../../../widgets/vehicle_seat_layout_picker.dart';
import 'create_trip_stepper.dart';
import 'create_trip_wizard_state.dart';

/// Wizard step 2 — when and how: departure date/time, published seats, price,
/// passenger notes, recurrence and the per-trip gender-mixing rule.
///
/// Seat *shape* is fixed by the vehicle (or its type template): this step only
/// changes how many of those seats are published.
class Step2Details extends StatelessWidget {
  const Step2Details({
    super.key,
    required this.wizard,
    required this.isLoadingVehicle,
    required this.currency,
    required this.priceSuggestion,
    required this.onChanged,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPickRecurrenceUntil,
    required this.onOpenVehicleSettings,
  });

  final CreateTripWizardState wizard;
  final bool isLoadingVehicle;

  /// Currency the trip will be published in. Derived by the backend from the
  /// departure point's country, so the driver never picks it.
  final String currency;

  /// Per-seat price band for this route; null while loading or unavailable.
  final TripPriceSuggestion? priceSuggestion;

  final VoidCallback onChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onPickRecurrenceUntil;
  final VoidCallback onOpenVehicleSettings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreateTripStepHeader(
            title: context.l10n.createTripWhenAndHow,
            subtitle: context.l10n.createTripWhenAndHowSubtitle,
          ),
          const SizedBox(height: 14),
          _buildScheduleCard(context),
          const SizedBox(height: 12),
          _buildSeatsCard(context),
          const SizedBox(height: 12),
          _buildPriceCard(context),
          const SizedBox(height: 12),
          _buildGenderMixingCard(context),
          const SizedBox(height: 12),
          _buildNotesAndRecurrenceRow(context),
        ],
      ),
    );
  }

  Widget _buildNotesAndRecurrenceRow(BuildContext context) {
    // Mockup shows notes + recurrence as sibling cards even on phone width.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildNotesCard(context)),
          const SizedBox(width: 12),
          Expanded(child: _buildRecurrenceCard(context)),
        ],
      ),
    );
  }

  // --- schedule ------------------------------------------------------------

  Widget _buildScheduleCard(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final departure = wizard.departureTime;

    // Designs use Western digits and the wide day-period word, neither of
    // which the Arabic locale data produces on its own.
    final dateText = departure == null
        ? ''
        : toWesternDigits(DateFormat.yMMMMEEEEd(locale).format(departure));
    final period = departure == null
        ? ''
        : (departure.hour < 12
              ? context.l10n.timePeriodAm
              : context.l10n.timePeriodPm);
    final timeText = departure == null
        ? ''
        : '${toWesternDigits(DateFormat('hh:mm').format(departure))} $period';

    // Two slots share one card, split by a hairline as in the mockup.
    return CreateTripCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildScheduleSlot(
                context,
                label: context.l10n.dateLabel,
                value: dateText,
                icon: IconsaxPlusBroken.calendar_1,
                onTap: onPickDate,
              ),
            ),
            const SizedBox(width: 6),
            VerticalDivider(width: 1, thickness: 1, color: T.outline(context)),
            const SizedBox(width: 6),
            Expanded(
              child: _buildScheduleSlot(
                context,
                label: context.l10n.departureTimeLabel,
                value: timeText,
                icon: IconsaxPlusBroken.clock,
                onTap: onPickTime,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSlot(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isEmpty = value.isEmpty;

    return Semantics(
      button: true,
      label: label,
      value: value,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            _iconChip(context, icon),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 12,
                      color: T.onSurfaceVariant(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty ? label : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isEmpty
                          ? T.textSecondary(context)
                          : T.onSurface(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: T.outlineVariant(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Brand-tinted rounded icon square used inside fields (cards use
  /// [CreateTripSectionHeader], which draws its own).
  Widget _iconChip(BuildContext context, IconData icon) {
    final primary = T.primary(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: primary, size: 15),
    );
  }

  // --- seats ---------------------------------------------------------------

  Widget _buildSeatsCard(BuildContext context) {
    final layout = wizard.layout;

    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateTripSectionHeader(
            icon: IconsaxPlusBroken.profile_2user,
            title: context.l10n.availableSeatsSection,
            subtitle: context.l10n.availableSeatsSectionSubtitle,
          ),
          const SizedBox(height: 12),
          if (isLoadingVehicle)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (layout == null || wizard.maxLayoutSeats <= 0)
            _buildMissingLayout(context)
          else
            VehicleSeatLayoutPicker(
              layout: layout,
              vehicleType: wizard.vehicleType,
              availableSeatCount: wizard.availableSeatCount,
              onAvailableSeatCountChanged: (value) {
                wizard.setAvailableSeatCount(value);
                onChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMissingLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.noSeatLayoutSet,
          style: AppTextStyles.bodyMedium.copyWith(
            color: T.onSurfaceVariant(context),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onOpenVehicleSettings,
          icon: Icon(IconsaxPlusBroken.car, color: T.primary(context)),
          label: Text(
            context.l10n.editVehicleSettings,
            style: AppTextStyles.bodyLarge.copyWith(
              color: T.primary(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: T.primary(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  // --- price ---------------------------------------------------------------

  Widget _buildPriceCard(BuildContext context) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateTripSectionHeader(
            icon: IconsaxPlusBroken.dollar_circle,
            title: context.l10n.pricePerSeat,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: T.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.outline(context)),
            ),
            child: Row(
              children: [
                Text(
                  context.l10n.currencyFullName(currency),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: T.onSurfaceVariant(context),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: wizard.priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (_) => onChanged(),
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.onSurface(context),
                    ),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.slate400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return context.l10n.enterPrice;
                      }
                      if (double.tryParse(v) == null) {
                        return context.l10n.enterValidNumber;
                      }
                      return null;
                    },
                  ),
                ),
                _buildCurrencyChip(context),
              ],
            ),
          ),
          _buildPriceSuggestion(context),
        ],
      ),
    );
  }

  /// Reads as a picker, but the currency comes from the departure point's
  /// country and the backend overrides anything the client sends — so this is
  /// a display of the resolved currency, not an editable control.
  Widget _buildCurrencyChip(BuildContext context) {
    return Semantics(
      readOnly: true,
      label: context.l10n.currencyFullName(currency),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: T.surfaceVariant(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currency,
                style: AppTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: T.onSurfaceVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceSuggestion(BuildContext context) {
    final suggestion = priceSuggestion;
    if (suggestion == null || !suggestion.hasBand) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            IconsaxPlusBroken.info_circle,
            size: 15,
            color: T.outlineVariant(context),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.suggestedPriceForRoute(
                suggestion.min.toStringAsFixed(0),
                suggestion.max.toStringAsFixed(0),
                context.l10n.currencyShortName(suggestion.currency),
              ),
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 12,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- prevent gender mixing ----------------------------------------------

  Widget _buildGenderMixingCard(BuildContext context) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateTripSectionHeader(
            icon: IconsaxPlusBroken.shield_tick,
            title: context.l10n.preventGenderMixing,
            trailing: Switch.adaptive(
              value: wizard.preventGenderMixing,
              activeThumbColor: T.primary(context),
              onChanged: (value) {
                wizard.preventGenderMixing = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.preventGenderMixingHint,
            style: AppTextStyles.bodyMedium.copyWith(
              color: T.onSurfaceVariant(context),
            ),
          ),
        ],
      ),
    );
  }

  // --- notes ---------------------------------------------------------------

  Widget _buildNotesCard(BuildContext context) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateTripSectionHeader(
            icon: IconsaxPlusBroken.message,
            title: context.l10n.notesForPassengers,
            titleSuffix: '(${context.l10n.optionalLabel})',
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: wizard.notesController,
            maxLines: 3,
            maxLength: 120,
            style: AppTextStyles.bodyLarge.copyWith(
              fontSize: 14,
              color: T.onSurface(context),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: T.surfaceVariant(context),
              hintText: context.l10n.tripNotesHint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: T.onSurfaceVariant(context),
              ),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: T.primary(context), width: 2),
              ),
              counterStyle: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- recurrence ----------------------------------------------------------

  Widget _buildRecurrenceCard(BuildContext context) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateTripSectionHeader(
            icon: IconsaxPlusBroken.refresh,
            title: context.l10n.tripRecurrence,
            trailing: Semantics(
              label: context.l10n.enableTripRecurrenceSemantic(
                wizard.enableRecurrence
                    ? context.l10n.recurrenceStateEnabled
                    : context.l10n.recurrenceStateDisabled,
              ),
              child: Switch.adaptive(
                value: wizard.enableRecurrence,
                activeThumbColor: T.primary(context),
                onChanged: (v) {
                  wizard.enableRecurrence = v;
                  onChanged();
                },
              ),
            ),
          ),
          if (!wizard.enableRecurrence)
            _buildRecurrenceCollapsedRow(context)
          else ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: T.surfaceVariant(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeToggle(
                      context,
                      title: context.l10n.recurrenceDaily,
                      isActive: wizard.recurrenceFrequency == 'daily',
                      onTap: () {
                        wizard.recurrenceFrequency = 'daily';
                        wizard.selectedWeekdays.clear();
                        onChanged();
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildModeToggle(
                      context,
                      title: context.l10n.recurrenceWeekly,
                      isActive: wizard.recurrenceFrequency == 'weekly',
                      onTap: () {
                        wizard.recurrenceFrequency = 'weekly';
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (wizard.recurrenceFrequency == 'weekly') ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.recurrenceDaysLabel,
                style: AppTextStyles.labelLarge.copyWith(
                  color: T.onSurface(context).withValues(alpha: 0.54),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CreateTripWizardState.weekdayKeys.map((key) {
                  final label = weekdayLabel(context, key);
                  final selected = wizard.selectedWeekdays.contains(key);
                  return Semantics(
                    button: true,
                    label: selected
                        ? context.l10n.weekdaySelectedSemantic(label)
                        : label,
                    child: FilterChip(
                      label: Text(
                        label,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? T.onPrimary(context)
                              : T.onSurface(context),
                        ),
                      ),
                      selected: selected,
                      onSelected: (v) {
                        if (v) {
                          wizard.selectedWeekdays.add(key);
                        } else {
                          wizard.selectedWeekdays.remove(key);
                        }
                        onChanged();
                      },
                      selectedColor: T.primary(context),
                      checkmarkColor: T.onPrimary(context),
                      backgroundColor: T.surface(context),
                      side: BorderSide(
                        color: selected
                            ? T.primary(context)
                            : T.outline(context),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            CreateTripPickerField(
              hint: context.l10n.recurrenceUntilHint,
              value: wizard.recurrenceUntil != null
                  ? DateFormat('yyyy-MM-dd').format(wizard.recurrenceUntil!)
                  : '',
              icon: IconsaxPlusBroken.calendar_1,
              iconColor: T.secondary(context),
              onTap: onPickRecurrenceUntil,
            ),
          ],
        ],
      ),
    );
  }

  /// Collapsed recurrence summary; tapping it turns recurrence on, which is
  /// what the trailing chevron promises.
  Widget _buildRecurrenceCollapsedRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            wizard.enableRecurrence = true;
            onChanged();
          },
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.recurrenceCollapsedHint,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    color: T.onSurfaceVariant(context),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: T.outlineVariant(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(
    BuildContext context, {
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? T.surface(context) : AppColors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: T.shadow(context),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive
                  ? T.primary(context)
                  : T.onSurfaceVariant(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Localized short weekday label for a recurrence key (`sun`…`sat`).
String weekdayLabel(BuildContext context, String key) {
  switch (key) {
    case 'sun':
      return context.l10n.weekdaySun;
    case 'mon':
      return context.l10n.weekdayMon;
    case 'tue':
      return context.l10n.weekdayTue;
    case 'wed':
      return context.l10n.weekdayWed;
    case 'thu':
      return context.l10n.weekdayThu;
    case 'fri':
      return context.l10n.weekdayFri;
    case 'sat':
      return context.l10n.weekdaySat;
    default:
      return key;
  }
}
