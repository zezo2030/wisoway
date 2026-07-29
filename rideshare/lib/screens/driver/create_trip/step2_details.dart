import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
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
    required this.onChanged,
    required this.onPickDate,
    required this.onPickTime,
    required this.onPickRecurrenceUntil,
    required this.onOpenVehicleSettings,
  });

  final CreateTripWizardState wizard;
  final bool isLoadingVehicle;
  final VoidCallback onChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onPickRecurrenceUntil;
  final VoidCallback onOpenVehicleSettings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreateTripStepHeader(
            title: context.l10n.createTripWhenAndHow,
            subtitle: context.l10n.createTripWhenAndHowSubtitle,
          ),
          const SizedBox(height: 20),
          _buildScheduleCard(context),
          const SizedBox(height: 16),
          _buildSeatsCard(context),
          const SizedBox(height: 16),
          _buildPriceCard(context),
          const SizedBox(height: 16),
          _buildGenderMixingCard(context),
          const SizedBox(height: 16),
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
    final dateText = departure == null
        ? ''
        : DateFormat.yMMMMEEEEd(locale).format(departure);
    final timeText = departure == null
        ? ''
        : DateFormat('hh:mm a', locale).format(departure);

    return CreateTripCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _labelled(
              context,
              label: context.l10n.dateLabel,
              child: CreateTripPickerField(
                hint: context.l10n.dateLabel,
                value: dateText,
                icon: IconsaxPlusBroken.calendar_1,
                iconColor: T.secondary(context),
                onTap: onPickDate,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _labelled(
              context,
              label: context.l10n.departureTimeLabel,
              child: CreateTripPickerField(
                hint: context.l10n.departureTimeLabel,
                value: timeText,
                icon: IconsaxPlusBroken.clock,
                iconColor: T.secondary(context),
                onTap: onPickTime,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelled(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: T.onSurface(context),
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  // --- seats ---------------------------------------------------------------

  Widget _buildSeatsCard(BuildContext context) {
    final layout = wizard.layout;

    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(IconsaxPlusBroken.profile_2user, color: T.primary(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.availableSeatsSection,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          Row(
            children: [
              Icon(IconsaxPlusBroken.wallet_1, color: T.primary(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.pricePerSeat,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: T.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.outline(context)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: T.primary(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'JOD',
                    style: AppTextStyles.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: T.primary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: wizard.priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => onChanged(),
                    style: AppTextStyles.titleMedium.copyWith(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                Text(
                  context.l10n.jordanianDinarLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
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

  // --- prevent gender mixing ----------------------------------------------

  Widget _buildGenderMixingCard(BuildContext context) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrapped in a transparent Material: the surrounding card paints its
          // own background, which would otherwise swallow the tile's ink.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: wizard.preventGenderMixing,
              onChanged: (value) {
                wizard.preventGenderMixing = value;
                onChanged();
              },
              title: Text(
                context.l10n.preventGenderMixing,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: T.onSurface(context),
                ),
              ),
              secondary: Icon(
                IconsaxPlusBroken.shield_tick,
                color: T.primary(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
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
          Row(
            children: [
              Icon(IconsaxPlusBroken.message, color: T.primary(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.notesForPassengers,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              Text(
                context.l10n.optionalLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: T.outlineVariant(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: wizard.notesController,
            maxLines: 4,
            maxLength: 120,
            style: AppTextStyles.bodyLarge.copyWith(
              color: T.onSurface(context),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: T.surface(context),
              hintText: context.l10n.tripNotesHint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: T.outline(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: T.primary(context), width: 2),
              ),
              counterStyle: AppTextStyles.bodyMedium.copyWith(
                color: T.onSurfaceVariant(context),
                fontSize: 12,
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
          Row(
            children: [
              Icon(IconsaxPlusBroken.refresh, color: T.primary(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.tripRecurrence,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              Semantics(
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
            ],
          ),
          if (!wizard.enableRecurrence)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.recurrenceDisabledHint,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: T.onSurfaceVariant(context),
                ),
              ),
            )
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
