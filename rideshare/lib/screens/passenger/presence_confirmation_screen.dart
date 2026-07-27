import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/route_names.dart';
import '../../core/services/presence_service.dart';
import '../../core/theme/colors.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/presence_models.dart';

class PresenceConfirmationScreen extends StatefulWidget {
  const PresenceConfirmationScreen({
    super.key,
    required this.bookingId,
    this.presenceGateway,
  });

  final String bookingId;
  final PresenceGateway? presenceGateway;

  @override
  State<PresenceConfirmationScreen> createState() =>
      _PresenceConfirmationScreenState();
}

class _PresenceConfirmationScreenState
    extends State<PresenceConfirmationScreen> {
  late final PresenceGateway _presenceGateway;
  late final Timer _clock;
  PresencePrompt? _prompt;
  PassengerPresenceStatus? _selectedStatus;
  PassengerPresenceStatus? _submittingStatus;
  DateTime? _loadedAt;
  Object? _loadError;
  bool _isEditing = true;

  @override
  void initState() {
    super.initState();
    _presenceGateway = widget.presenceGateway ?? PresenceService();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _prompt != null) setState(() {});
    });
    _loadPrompt();
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _loadPrompt() async {
    setState(() => _loadError = null);
    try {
      final prompt = await _presenceGateway.getPrompt(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _prompt = prompt;
        _selectedStatus = prompt.declaredStatus;
        _loadedAt = DateTime.now();
        _isEditing = prompt.declaredStatus == null;
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _submit(PassengerPresenceStatus status) async {
    final prompt = _prompt;
    if (prompt == null || !_windowIsOpen(prompt)) return;
    setState(() => _submittingStatus = status);

    try {
      final seatNumbers = prompt.seats.map((seat) => seat.seatNumber).toList();
      await _presenceGateway.declare(widget.bookingId, status, seatNumbers);
      if (!mounted) return;
      setState(() {
        _selectedStatus = status;
        _submittingStatus = null;
        _isEditing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.presenceSubmitFailed)),
      );
    }
  }

  bool _windowIsOpen(PresencePrompt prompt) {
    final now = DateTime.now();
    return prompt.window.isOpen &&
        !now.isBefore(prompt.window.opensAt) &&
        !now.isAfter(prompt.window.closesAt);
  }

  Duration _departureRemaining(PresencePrompt prompt) {
    final loadedAt = _loadedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(loadedAt).inSeconds;
    return Duration(
      seconds: math.max(prompt.secondsUntilDeparture - elapsed, 0),
    );
  }

  Duration _windowRemaining(PresencePrompt prompt) {
    final seconds = prompt.window.closesAt.difference(DateTime.now()).inSeconds;
    return Duration(seconds: math.max(seconds, 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _PresenceHeader(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loadError != null) {
      return _PresenceLoadError(onRetry: _loadPrompt);
    }
    final prompt = _prompt;
    if (prompt == null) return const _PresenceLoading();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 430 ? 12.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            AppSpacing.sm,
            horizontalPadding,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  _TripOverviewCard(
                    prompt: prompt,
                    departureRemaining: _departureRemaining(prompt),
                  ),
                  AppSpacing.verticalGapLg,
                  _questionSection(prompt),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _questionSection(PresencePrompt prompt) {
    final windowOpen = _windowIsOpen(prompt);
    if (!windowOpen) {
      return _PresenceClosedCard(selectedStatus: _selectedStatus);
    }
    if (_selectedStatus != null && !_isEditing) {
      return _PresenceConfirmedCard(
        status: _selectedStatus!,
        onEdit: () => setState(() => _isEditing = true),
      );
    }
    return _PresenceQuestionCard(
      selectedStatus: _selectedStatus,
      submittingStatus: _submittingStatus,
      windowRemaining: _windowRemaining(prompt),
      onSelected: _submit,
    );
  }
}

class _PresenceHeader extends StatelessWidget {
  const _PresenceHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Padding(
        padding: AppSpacing.horizontalLg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _HeaderButton(
                icon: Icons.keyboard_arrow_down_rounded,
                semanticsLabel: MaterialLocalizations.of(
                  context,
                ).closeButtonLabel,
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.presenceScreenTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppSpacing.verticalGapXs,
                  Text(
                    context.l10n.presenceScreenSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: T.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, RouteNames.support),
                icon: const Icon(Icons.headset_mic_outlined, size: 20),
                label: Text(context.l10n.presenceHelp),
                style: OutlinedButton.styleFrom(
                  foregroundColor: T.onSurface(context),
                  minimumSize: const Size(96, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(color: T.outlineVariant(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 32),
        style: IconButton.styleFrom(
          backgroundColor: T.surface(context),
          minimumSize: const Size(52, 52),
          side: BorderSide(color: T.outlineVariant(context)),
          shadowColor: Colors.black.withValues(alpha: 0.08),
          elevation: 2,
        ),
      ),
    );
  }
}

class _TripOverviewCard extends StatelessWidget {
  const _TripOverviewCard({
    required this.prompt,
    required this.departureRemaining,
  });

  final PresencePrompt prompt;
  final Duration departureRemaining;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _DriverVehicleRow(
              prompt: prompt,
              departureRemaining: departureRemaining,
            ),
          ),
          Divider(color: T.outlineVariant(context)),
          _PickupMapRow(prompt: prompt),
        ],
      ),
    );
  }
}

class _DriverVehicleRow extends StatelessWidget {
  const _DriverVehicleRow({
    required this.prompt,
    required this.departureRemaining,
  });

  final PresencePrompt prompt;
  final Duration departureRemaining;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        return Row(
          children: [
            _DriverIdentity(driver: prompt.driver, compact: compact),
            AppSpacing.horizontalGapSm,
            Expanded(
              child: _VehicleImage(vehicle: prompt.vehicle, compact: compact),
            ),
            SizedBox(
              width: compact ? 92 : 132,
              child: _DepartureCountdown(remaining: departureRemaining),
            ),
          ],
        );
      },
    );
  }
}

class _DriverIdentity extends StatelessWidget {
  const _DriverIdentity({required this.driver, required this.compact});

  final PresenceDriver? driver;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 154 : 190,
      child: Row(
        children: [
          _DriverAvatar(photoUrl: driver?.photoUrl, compact: compact),
          AppSpacing.horizontalGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver?.name.isNotEmpty == true ? driver!.name : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.verticalGapXs,
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _ratingLabel(driver),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                AppSpacing.verticalGapXs,
                Text(
                  'سائق موثّق',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: T.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(PresenceDriver? driver) {
    final rating = driver?.rating;
    if (rating == null) return '—';
    return '${rating.toStringAsFixed(1)} (${driver?.ratingCount ?? 0})';
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({this.photoUrl, required this.compact});

  final String? photoUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/presence_driver_fallback.png',
      fit: BoxFit.cover,
    );
    return Container(
      width: compact ? 60 : 76,
      height: compact ? 60 : 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: T.outlineVariant(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl?.isNotEmpty == true
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.vehicle, required this.compact});

  final PresenceVehicle? vehicle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/presence_vehicle_fallback.png',
      fit: BoxFit.contain,
    );
    return Column(
      children: [
        SizedBox(
          height: compact ? 60 : 76,
          child: vehicle?.carImageUrl?.isNotEmpty == true
              ? Image.network(
                  vehicle!.carImageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
        Text(
          _vehicleLabel(vehicle),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            vehicle?.plateNumber.isNotEmpty == true
                ? vehicle!.plateNumber
                : '—',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _vehicleLabel(PresenceVehicle? vehicle) {
    final parts = [
      vehicle?.vehicleType,
      vehicle?.model,
    ].where((part) => part?.trim().isNotEmpty == true);
    return parts.map((part) => part!.trim()).join(' • ');
  }
}

class _DepartureCountdown extends StatelessWidget {
  const _DepartureCountdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _durationLabel(remaining);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            context.l10n.presenceDriverStartsAfter,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          AppSpacing.verticalGapSm,
          Semantics(
            liveRegion: true,
            label: timeLabel,
            child: Text(
              timeLabel,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: T.primary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                IconsaxPlusLinear.clock,
                size: 16,
                color: T.primary(context),
              ),
              const SizedBox(width: 4),
              Text(
                context.l10n.presenceMinutes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickupMapRow extends StatelessWidget {
  const _PickupMapRow({required this.prompt});

  final PresencePrompt prompt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final detailsWidth = (constraints.maxWidth * 0.32).clamp(120.0, 210.0);
        return SizedBox(
          height: 182,
          child: Row(
            children: [
              SizedBox(
                width: detailsWidth,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            IconsaxPlusBold.location,
                            color: T.primary(context),
                          ),
                          AppSpacing.horizontalGapSm,
                          Expanded(
                            child: Text(
                              context.l10n.presencePickupTitle,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: T.primary(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalGapSm,
                      Text(
                        prompt.pickup.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (prompt.pickup.address?.trim().isNotEmpty == true) ...[
                        AppSpacing.verticalGapXs,
                        Text(
                          prompt.pickup.address!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: T.outlineVariant(context)),
              const Expanded(child: _PresenceMap()),
            ],
          ),
        );
      },
    );
  }
}

class _PresenceMap extends StatelessWidget {
  const _PresenceMap();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PresenceMapPainter(
              darkMode: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
          Center(
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: T.primary(context).withValues(alpha: 0.25),
                ),
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: T.primary(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 54,
            top: 48,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: T.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.directions_car_filled_rounded,
                  size: 20,
                  color: T.onSurface(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceQuestionCard extends StatelessWidget {
  const _PresenceQuestionCard({
    required this.selectedStatus,
    required this.submittingStatus,
    required this.windowRemaining,
    required this.onSelected,
  });

  final PassengerPresenceStatus? selectedStatus;
  final PassengerPresenceStatus? submittingStatus;
  final Duration windowRemaining;
  final ValueChanged<PassengerPresenceStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            _QuestionHeading(),
            AppSpacing.verticalGapLg,
            _PresenceInfoBox(),
            AppSpacing.verticalGapLg,
            _PresenceActions(
              selectedStatus: selectedStatus,
              submittingStatus: submittingStatus,
              onSelected: onSelected,
            ),
            AppSpacing.verticalGapLg,
            _PrivacyLine(),
            AppSpacing.verticalGapMd,
            _RequestCountdown(remaining: windowRemaining),
          ],
        ),
      ),
    );
  }
}

class _QuestionHeading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: T.primary(context).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            IconsaxPlusBold.notification,
            color: T.primary(context),
            size: 27,
          ),
        ),
        AppSpacing.verticalGapMd,
        Text(
          context.l10n.presenceQuestionTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        AppSpacing.verticalGapXs,
        Text(
          context.l10n.presenceQuestionSubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: T.textSecondary(context)),
        ),
      ],
    );
  }
}

class _PresenceInfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: T.primary(context).withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            IconsaxPlusBold.info_circle,
            color: T.primary(context),
            size: 26,
          ),
          AppSpacing.horizontalGapMd,
          Expanded(
            child: Text(
              context.l10n.presenceInfoBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.8,
                color: T.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceActions extends StatelessWidget {
  const _PresenceActions({
    required this.selectedStatus,
    required this.submittingStatus,
    required this.onSelected,
  });

  final PassengerPresenceStatus? selectedStatus;
  final PassengerPresenceStatus? submittingStatus;
  final ValueChanged<PassengerPresenceStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _PresenceActionSpec.inVehicle(context),
      _PresenceActionSpec.onMyWay(context),
      _PresenceActionSpec.notRiding(context),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            children: [
              for (final action in actions) ...[
                _card(action),
                if (action != actions.last) AppSpacing.verticalGapSm,
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final action in actions) ...[
                Expanded(child: _card(action)),
                if (action != actions.last) AppSpacing.horizontalGapMd,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _card(_PresenceActionSpec action) {
    return _PresenceActionCard(
      spec: action,
      selectedStatus: selectedStatus,
      submittingStatus: submittingStatus,
      onPressed: () => onSelected(action.status),
    );
  }
}

class _PresenceActionCard extends StatelessWidget {
  const _PresenceActionCard({
    required this.spec,
    required this.selectedStatus,
    required this.submittingStatus,
    required this.onPressed,
  });

  final _PresenceActionSpec spec;
  final PassengerPresenceStatus? selectedStatus;
  final PassengerPresenceStatus? submittingStatus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = selectedStatus == spec.status;
    final submitting = submittingStatus == spec.status;
    final disabled = submittingStatus != null;
    final filled = spec.status == PassengerPresenceStatus.inVehicle;
    final foreground = filled ? Colors.white : T.onSurface(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: filled
            ? T.primary(context)
            : selected
            ? T.primary(context).withValues(alpha: 0.08)
            : T.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: filled || selected
                    ? T.primary(context)
                    : T.outline(context),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionIcon(spec: spec, filled: filled, submitting: submitting),
                AppSpacing.verticalGapMd,
                Text(
                  spec.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.verticalGapXs,
                Text(
                  spec.subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: filled
                        ? Colors.white.withValues(alpha: 0.86)
                        : T.textSecondary(context),
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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.spec,
    required this.filled,
    required this.submitting,
  });

  final _PresenceActionSpec spec;
  final bool filled;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: filled ? Colors.white.withValues(alpha: 0.94) : spec.tintColor,
        shape: BoxShape.circle,
      ),
      child: submitting
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: filled ? T.primary(context) : spec.iconColor,
              ),
            )
          : Icon(
              spec.icon,
              size: 31,
              color: filled ? T.primary(context) : spec.iconColor,
            ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 20, color: T.textSecondary(context)),
        AppSpacing.horizontalGapSm,
        Flexible(
          child: Text(
            context.l10n.presencePrivacyLine,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _RequestCountdown extends StatelessWidget {
  const _RequestCountdown({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final label = _durationLabel(remaining);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: T.surfaceVariant(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            IconsaxPlusLinear.clock,
            size: 20,
            color: T.textSecondary(context),
          ),
          AppSpacing.horizontalGapSm,
          Text(
            context.l10n.presenceRequestEndsAfter,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: T.primary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceConfirmedCard extends StatelessWidget {
  const _PresenceConfirmedCard({required this.status, required this.onEdit});

  final PassengerPresenceStatus status;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: T.primary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconsaxPlusBold.tick_circle,
                size: 38,
                color: T.primary(context),
              ),
            ),
            AppSpacing.verticalGapLg,
            Text(
              context.l10n.presenceConfirmedTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            AppSpacing.verticalGapSm,
            Text(
              context.l10n.presenceConfirmedBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            AppSpacing.verticalGapMd,
            _PresenceStatusPill(status: status),
            AppSpacing.verticalGapLg,
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.presenceEdit),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceClosedCard extends StatelessWidget {
  const _PresenceClosedCard({required this.selectedStatus});

  final PassengerPresenceStatus? selectedStatus;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Icon(
              IconsaxPlusLinear.clock,
              color: T.textSecondary(context),
              size: 52,
            ),
            AppSpacing.verticalGapMd,
            Text(
              context.l10n.presenceWindowClosedTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            AppSpacing.verticalGapSm,
            Text(
              context.l10n.presenceWindowClosedBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (selectedStatus != null) ...[
              AppSpacing.verticalGapLg,
              _PresenceStatusPill(status: selectedStatus!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresenceStatusPill extends StatelessWidget {
  const _PresenceStatusPill({required this.status});

  final PassengerPresenceStatus status;

  @override
  Widget build(BuildContext context) {
    final spec = _PresenceActionSpec.forStatus(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: spec.tintColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 19, color: spec.iconColor),
          AppSpacing.horizontalGapSm,
          Text(
            spec.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: spec.iconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceLoading extends StatelessWidget {
  const _PresenceLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: T.primary(context)),
          AppSpacing.verticalGapMd,
          Text(context.l10n.loading),
        ],
      ),
    );
  }
}

class _PresenceLoadError extends StatelessWidget {
  const _PresenceLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXxl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              IconsaxPlusLinear.info_circle,
              size: 52,
              color: T.error(context),
            ),
            AppSpacing.verticalGapMd,
            Text(
              context.l10n.presenceLoadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            AppSpacing.verticalGapLg,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: T.outlineVariant(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PresenceActionSpec {
  const _PresenceActionSpec({
    required this.status,
    required this.title,
    required this.subtitle,
    required this.appearance,
  });

  final PassengerPresenceStatus status;
  final String title;
  final String subtitle;
  final _PresenceActionAppearance appearance;
  IconData get icon => appearance.icon;
  Color get iconColor => appearance.iconColor;
  Color get tintColor => appearance.tintColor;

  factory _PresenceActionSpec.inVehicle(BuildContext context) {
    return _PresenceActionSpec(
      status: PassengerPresenceStatus.inVehicle,
      title: context.l10n.presenceInVehicleTitle,
      subtitle: context.l10n.presenceInVehicleSubtitle,
      appearance: _PresenceActionAppearance(
        icon: Icons.check_rounded,
        iconColor: T.primary(context),
        tintColor: T.primary(context).withValues(alpha: 0.1),
      ),
    );
  }

  factory _PresenceActionSpec.onMyWay(BuildContext context) {
    return _PresenceActionSpec(
      status: PassengerPresenceStatus.onMyWay,
      title: context.l10n.presenceOnMyWayTitle,
      subtitle: context.l10n.presenceOnMyWaySubtitle,
      appearance: _PresenceActionAppearance(
        icon: Icons.directions_walk_rounded,
        iconColor: AppColors.warningDark,
        tintColor: AppColors.warning.withValues(alpha: 0.13),
      ),
    );
  }

  factory _PresenceActionSpec.notRiding(BuildContext context) {
    return _PresenceActionSpec(
      status: PassengerPresenceStatus.notRiding,
      title: context.l10n.presenceNotRidingTitle,
      subtitle: context.l10n.presenceNotRidingSubtitle,
      appearance: _PresenceActionAppearance(
        icon: Icons.close_rounded,
        iconColor: AppColors.errorDark,
        tintColor: AppColors.error.withValues(alpha: 0.12),
      ),
    );
  }

  factory _PresenceActionSpec.forStatus(
    BuildContext context,
    PassengerPresenceStatus status,
  ) {
    return switch (status) {
      PassengerPresenceStatus.inVehicle => _PresenceActionSpec.inVehicle(
        context,
      ),
      PassengerPresenceStatus.onMyWay => _PresenceActionSpec.onMyWay(context),
      PassengerPresenceStatus.notRiding => _PresenceActionSpec.notRiding(
        context,
      ),
    };
  }
}

class _PresenceActionAppearance {
  const _PresenceActionAppearance({
    required this.icon,
    required this.iconColor,
    required this.tintColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color tintColor;
}

class _PresenceMapPainter extends CustomPainter {
  const _PresenceMapPainter({required this.darkMode});

  final bool darkMode;

  @override
  void paint(Canvas canvas, Size size) {
    final background = darkMode
        ? const Color(0xFF1E293B)
        : const Color(0xFFF2F6F4);
    final road = darkMode ? const Color(0xFF334155) : const Color(0xFFFFFFFF);
    final minorRoad = darkMode
        ? const Color(0xFF293548)
        : const Color(0xFFE6ECE9);
    final park = darkMode ? const Color(0xFF174C46) : const Color(0xFFDDF3E6);

    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    _paintParks(canvas, size, park);
    _paintRoads(canvas, size, minorRoad, 7);
    _paintRoads(canvas, size, road, 15);
  }

  void _paintParks(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .07, size.height * .12, 68, 48),
        const Radius.circular(12),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .72, size.height * .58, 84, 56),
        const Radius.circular(14),
      ),
      paint,
    );
  }

  void _paintRoads(Canvas canvas, Size size, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paths = [
      [
        Offset(-20, size.height * .76),
        Offset(size.width + 20, size.height * .3),
      ],
      [
        Offset(size.width * .18, -20),
        Offset(size.width * .42, size.height + 20),
      ],
      [
        Offset(size.width * .68, -20),
        Offset(size.width * .9, size.height + 20),
      ],
    ];
    for (final points in paths) {
      canvas.drawLine(points.first, points.last, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PresenceMapPainter oldDelegate) {
    return oldDelegate.darkMode != darkMode;
  }
}

String _durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
