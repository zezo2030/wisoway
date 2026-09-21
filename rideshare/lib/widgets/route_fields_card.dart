import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;

import '../core/services/location_service.dart';
import '../core/services/saved_places_service.dart';
import '../core/theme/colors.dart';
import '../l10n/l10n_extensions.dart';
import '../models/location_model.dart';
import '../screens/location/route_search_screen.dart';
import 'location/place_field_block.dart';

/// The origin/destination pair as it appears on a form: two read-only blocks,
/// stacked, in inDrive's route-form shape.
///
/// Tapping either row opens the full-screen route search focused on that row —
/// nothing is typed here, which is what keeps a single search path in the app.
/// Optionally auto-fills the origin from the device location on first build,
/// the way inDrive pre-fills point A.
class RouteFieldsCard extends StatefulWidget {
  const RouteFieldsCard({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
    this.originLabel,
    this.destinationLabel,
    this.originHint,
    this.destinationHint,
    this.autofillOrigin = false,
    this.enabled = true,
    this.disabledHint,
    this.locationService,
    this.savedPlaces,
  });

  final LocationModel? from;
  final LocationModel? to;

  /// Called with the endpoints after the search screen closes.
  final void Function(LocationModel? from, LocationModel? to) onChanged;

  final String? originLabel;
  final String? destinationLabel;
  final String? originHint;
  final String? destinationHint;

  /// Fill the origin from the device location when it is empty and permission
  /// is already granted. Never prompts for the permission.
  final bool autofillOrigin;

  /// False while a prerequisite is missing; tapping then shows [disabledHint].
  final bool enabled;
  final String? disabledHint;

  final LocationService? locationService;
  final SavedPlacesService? savedPlaces;

  @override
  State<RouteFieldsCard> createState() => _RouteFieldsCardState();
}

class _RouteFieldsCardState extends State<RouteFieldsCard> {
  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  bool _isAutofilling = false;
  bool _autofillAttempted = false;

  @override
  void initState() {
    super.initState();
    _maybeAutofillOrigin();
  }

  @override
  void didUpdateWidget(covariant RouteFieldsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAutofillOrigin();
  }

  /// Fill point A with where the user is, in the background.
  ///
  /// Runs at most once and only with a permission the user already granted —
  /// opening a form must not trigger a location prompt.
  Future<void> _maybeAutofillOrigin() async {
    if (!widget.autofillOrigin ||
        _autofillAttempted ||
        widget.from != null ||
        !widget.enabled) {
      return;
    }
    _autofillAttempted = true;

    try {
      final permission = await _locationService.checkPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return;
      if (!await _locationService.isLocationSharingEnabled()) return;

      if (mounted) setState(() => _isAutofilling = true);
      final location = await _locationService.getCurrentLocation();
      // The user may have picked an origin while GPS was resolving; their
      // choice wins over the automatic one.
      if (!mounted || widget.from != null) return;
      setState(() => _isAutofilling = false);
      widget.onChanged(location, widget.to);
    } catch (_) {
      if (mounted) setState(() => _isAutofilling = false);
    }
  }

  SavedPlacesService get _savedPlaces =>
      widget.savedPlaces ?? SavedPlacesService(userId: 'guest');

  Future<void> _openSearch(RouteField field) async {
    if (!widget.enabled) {
      final hint = widget.disabledHint;
      if (hint != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(hint)));
      }
      return;
    }

    final selection = await Navigator.of(context).push<RouteSelection>(
      MaterialPageRoute(
        builder: (_) => RouteSearchScreen(
          focusField: field,
          savedPlaces: _savedPlaces,
          from: widget.from,
          to: widget.to,
          locationService: widget.locationService,
        ),
      ),
    );

    if (selection == null || !mounted) return;
    widget.onChanged(selection.from, selection.to);
  }

  @override
  Widget build(BuildContext context) {
    // inDrive's route form: each endpoint is its own filled block with a
    // chevron, so both read as things you open rather than fields you type in.
    return Column(
      children: [
        PlaceFieldBlock(
          label: widget.originLabel,
          value: widget.from?.name,
          hint: widget.originHint ?? context.l10n.routeSearchFromHint,
          indicator: RouteEndpointRing(color: T.success(context)),
          busy: _isAutofilling,
          onTap: () => _openSearch(RouteField.origin),
        ),
        const SizedBox(height: 8),
        PlaceFieldBlock(
          label: widget.destinationLabel,
          value: widget.to?.name,
          hint: widget.destinationHint ?? context.l10n.routeSearchToHint,
          indicator: RouteEndpointRing(color: T.error(context)),
          onTap: () => _openSearch(RouteField.destination),
        ),
      ],
    );
  }
}
