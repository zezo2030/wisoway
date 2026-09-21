import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/saved_places_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../widgets/route_fields_card.dart';
import '../../location/route_search_screen.dart';
import 'create_trip_stepper.dart';
import 'create_trip_wizard_state.dart';

/// Wizard step 1 — pick the route: origin, destination and optional stops.
///
/// Each endpoint opens the inDrive-style place search, which looks up any
/// place on the map and orders results by distance from the driver's device
/// location, nearest first.
class Step1Route extends StatelessWidget {
  const Step1Route({
    super.key,
    required this.wizard,
    required this.onChanged,
    required this.savedPlaces,
  });

  final CreateTripWizardState wizard;

  /// Invoked after any mutation so the shell can rebuild (footer gating).
  final VoidCallback onChanged;

  /// Backs the search screen's shortcuts and recent places.
  final SavedPlacesService savedPlaces;

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
    return RouteFieldsCard(
      from: wizard.from,
      to: wizard.to,
      originLabel: context.l10n.fromLabel,
      destinationLabel: context.l10n.toLabel,
      originHint: context.l10n.departurePointTitle,
      destinationHint: context.l10n.arrivalPointTitle,
      savedPlaces: savedPlaces,
      onChanged: (from, to) {
        wizard.from = from;
        wizard.to = to;
        wizard.fromController.text = from?.name ?? '';
        wizard.toController.text = to?.name ?? '';
        onChanged();
      },
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
    // Stops sit between the two endpoints, so open the map midway along the
    // route when both are known rather than wherever the phone happens to be.
    LatLng? fallback;
    if (wizard.from != null && wizard.to != null) {
      fallback = LatLng(
        (wizard.from!.latitude + wizard.to!.latitude) / 2,
        (wizard.from!.longitude + wizard.to!.longitude) / 2,
      );
    }

    // A stop is searched for by name like any other place, with the map still
    // one tap away inside the search screen.
    final selection = await Navigator.push<RouteSelection>(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSearchScreen.singlePoint(
          savedPlaces: savedPlaces,
          title: context.l10n.selectStopNumber(wizard.stops.length + 1),
          hint: context.l10n.routeSearchStopHint,
          mapFallbackCenter: fallback,
        ),
      ),
    );

    final location = selection?.from;
    if (location == null) return;
    wizard.addStop(location);
    onChanged();
  }
}
