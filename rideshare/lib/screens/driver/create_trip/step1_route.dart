import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/location_model.dart';
import '../../../widgets/location_autocomplete_field.dart';
import '../../../widgets/location_picker_widget.dart';
import 'create_trip_stepper.dart';
import 'create_trip_wizard_state.dart';

/// Wizard step 1 — pick the route: origin, destination and optional stops.
class Step1Route extends StatelessWidget {
  const Step1Route({super.key, required this.wizard, required this.onChanged});

  final CreateTripWizardState wizard;

  /// Invoked after any mutation so the shell can rebuild (footer gating).
  final VoidCallback onChanged;

  static const double _avgHighwayKmh = 80;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreateTripStepHeader(
            title: context.l10n.createTripRouteTitle,
            subtitle: context.l10n.createTripRouteSubtitle,
          ),
          const SizedBox(height: 20),
          _buildLocationsCard(context),
          const SizedBox(height: 12),
          _buildAddStopButton(context),
          if (wizard.stops.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildStopsList(context),
          ],
          if (wizard.from != null && wizard.to != null) ...[
            const SizedBox(height: 16),
            _buildRoutePreview(context),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationsCard(BuildContext context) {
    return CreateTripCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PositionedDirectional(
                start: 23,
                top: 36,
                bottom: 36,
                child: Container(
                  width: 2,
                  color: T.outlineVariant(context).withValues(alpha: 0.45),
                ),
              ),
              Column(
                children: [
                  _labelledField(
                    context,
                    label: context.l10n.fromLabel,
                    labelColor: T.success(context),
                    child: LocationAutocompleteField(
                      controller: wizard.fromController,
                      hint: context.l10n.departurePointTitle,
                      mapPickerTitle: context.l10n.selectOriginPoint,
                      icon: Icons.trip_origin,
                      iconColor: T.success(context),
                      initialLocation: wizard.from,
                      onLocationSelected: (location) {
                        wizard.from = location;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _labelledField(
                    context,
                    label: context.l10n.toLabel,
                    labelColor: T.error(context),
                    child: LocationAutocompleteField(
                      controller: wizard.toController,
                      hint: context.l10n.arrivalPointTitle,
                      mapPickerTitle: context.l10n.selectDestination,
                      icon: Icons.location_on,
                      iconColor: T.error(context),
                      initialLocation: wizard.to,
                      onLocationSelected: (location) {
                        wizard.to = location;
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labelledField(
    BuildContext context, {
    required String label,
    required Color labelColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildAddStopButton(BuildContext context) {
    final canAdd = wizard.canAddStop;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: canAdd ? () => _addStop(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: T.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canAdd
                  ? T.primary(context).withValues(alpha: 0.45)
                  : T.outline(context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: T.primary(context).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: canAdd
                      ? T.primary(context)
                      : T.onSurfaceVariant(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.addStop,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: canAdd
                            ? T.onSurface(context)
                            : T.onSurfaceVariant(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.addStopSubtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopsList(BuildContext context) {
    return CreateTripCard(
      child: Column(
        children: List.generate(wizard.stops.length, (i) {
          final stop = wizard.stops[i];
          return Padding(
            padding: EdgeInsets.only(
              bottom: i == wizard.stops.length - 1 ? 0 : 8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: T.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.outline(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: T.secondary(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: T.secondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      stop.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: T.onSurface(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: context.l10n.deleteStopNumber(i + 1),
                    child: GestureDetector(
                      onTap: () {
                        wizard.removeStopAt(i);
                        onChanged();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: T.error(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRoutePreview(BuildContext context) {
    final from = wizard.from!;
    final to = wizard.to!;
    final km = LocationService().calculateDistanceBetweenLocations(from, to);
    final distanceText = context.l10n.distanceKm('${km.round()}');
    final minutesTotal = (km / _avgHighwayKmh * 60).round().clamp(1, 24 * 60);
    final hours = minutesTotal ~/ 60;
    final minutes = minutesTotal % 60;
    final durationText = hours > 0
        ? context.l10n.approxDurationHoursMinutes(hours, minutes)
        : context.l10n.approxDurationMinutesOnly(minutes);

    final fromLatLng = LatLng(from.latitude, from.longitude);
    final toLatLng = LatLng(to.latitude, to.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(
        from.latitude < to.latitude ? from.latitude : to.latitude,
        from.longitude < to.longitude ? from.longitude : to.longitude,
      ),
      northeast: LatLng(
        from.latitude > to.latitude ? from.latitude : to.latitude,
        from.longitude > to.longitude ? from.longitude : to.longitude,
      ),
    );

    return CreateTripCard(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (from.latitude + to.latitude) / 2,
                    (from.longitude + to.longitude) / 2,
                  ),
                  zoom: 7,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('from'),
                    position: fromLatLng,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('to'),
                    position: toLatLng,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [fromLatLng, toLatLng],
                    color: T.primary(context),
                    width: 4,
                  ),
                },
                liteModeEnabled: true,
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                onMapCreated: (controller) {
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 48),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricChip(
                  context,
                  icon: IconsaxPlusBroken.routing,
                  text: context.l10n.approxDistanceLabel(distanceText),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricChip(
                  context,
                  icon: IconsaxPlusBroken.clock,
                  text: context.l10n.approxDurationLabel(durationText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: T.primary(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: T.primary(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: T.onSurface(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addStop(BuildContext context) async {
    final location = await Navigator.push<LocationModel>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          title: context.l10n.selectStopNumber(wizard.stops.length + 1),
          onLocationSelected: (_) {},
        ),
      ),
    );
    if (location == null) return;
    wizard.addStop(location);
    onChanged();
  }
}
