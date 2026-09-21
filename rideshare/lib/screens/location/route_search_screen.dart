import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/location_service.dart';
import '../../core/services/saved_places_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/location_model.dart';
import '../../widgets/location/place_result_row.dart';
import 'map_point_picker_screen.dart';

/// Which of the two route endpoints the search screen is editing.
enum RouteField { origin, destination }

/// What the search screen hands back: the endpoints as they stand on exit.
class RouteSelection {
  final LocationModel? from;
  final LocationModel? to;

  const RouteSelection({this.from, this.to});
}

/// Full-screen picker for a trip's start and end points.
///
/// Mirrors inDrive's route screen: both fields live in the header, the list
/// below shows shortcuts and recent places until the user types, and choosing
/// a result for the origin moves focus to the destination rather than closing.
/// Choosing a destination closes the screen — there is no separate confirmation
/// step, since the map picker already confirms its own point.
///
/// Pops a [RouteSelection], or null when the user backs out unchanged.
class RouteSearchScreen extends StatefulWidget {
  const RouteSearchScreen({
    super.key,
    required this.focusField,
    required this.savedPlaces,
    this.from,
    this.to,
    this.locationService,
  }) : singlePointTitle = null,
       singlePointHint = null,
       mapFallbackCenter = null;

  /// Search for one place instead of a pair — a stop, or any single point.
  ///
  /// Shows one field, and pops as soon as a place is confirmed. The chosen
  /// place comes back as [RouteSelection.from].
  const RouteSearchScreen.singlePoint({
    super.key,
    required this.savedPlaces,
    required String title,
    String? hint,
    LocationModel? initial,
    this.mapFallbackCenter,
    this.locationService,
  }) : singlePointTitle = title,
       singlePointHint = hint,
       focusField = RouteField.origin,
       from = initial,
       to = null;

  /// Field the keyboard opens on, matching the field the user tapped.
  final RouteField focusField;

  final SavedPlacesService savedPlaces;
  final LocationModel? from;
  final LocationModel? to;

  /// Where the map picker opens when the device location is unavailable
  /// (e.g. midway along a route when picking a stop).
  final LatLng? mapFallbackCenter;

  final LocationService? locationService;

  /// Title of the single-point variant; null in the two-field variant.
  final String? singlePointTitle;
  final String? singlePointHint;

  bool get isSinglePoint => singlePointTitle != null;

  @override
  State<RouteSearchScreen> createState() => _RouteSearchScreenState();
}

/// How the results area is currently occupied.
enum _ListMode { defaults, results, empty, error, rateLimited }

class _RouteSearchScreenState extends State<RouteSearchScreen> {
  static const Duration _debounce = Duration(milliseconds: 250);
  static const int _minQueryLength = 2;

  late final LocationService _locationService =
      widget.locationService ?? LocationService();

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  LocationModel? _from;
  LocationModel? _to;
  late RouteField _active;

  /// Independent per field so a session is never shared between two searches.
  String _originSession = const Uuid().v4();
  String _destinationSession = const Uuid().v4();

  Timer? _debounceTimer;
  CancelToken? _inFlight;

  /// Every request carries a sequence number; a response whose number is not
  /// the latest is discarded, so a slow reply can never overwrite newer results.
  int _sequence = 0;

  List<PlaceSuggestion> _suggestions = const [];
  _ListMode _mode = _ListMode.defaults;
  bool _isLoading = false;

  List<SavedPlace> _shortcuts = const [];
  List<SavedPlace> _recents = const [];

  /// Device location, fetched once and reused to bias every search rather than
  /// asking the GPS again on each keystroke.
  LatLng? _deviceLocation;

  /// Camera of the inline map preview, kept so the view can follow the device
  /// location when it arrives after the map was already created.
  GoogleMapController? _previewController;

  /// Country-level view for the preview when nothing better is known yet.
  static const LatLng _fallbackMapCenter = LatLng(31.9539, 35.9106);
  static const double _previewZoom = 14;

  /// Where the inline preview looks, and where the full picker opens from.
  LatLng get _previewCenter => _searchContext ?? _fallbackMapCenter;

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    _to = widget.to;
    _active = widget.focusField;
    _originController.text = widget.from?.name ?? '';
    _destinationController.text = widget.to?.name ?? '';

    _loadSavedPlaces();
    _primeDeviceLocation();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNodeFor(_active).requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _previewController?.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  // --- state helpers -------------------------------------------------------

  TextEditingController get _activeController =>
      _active == RouteField.origin ? _originController : _destinationController;

  FocusNode _focusNodeFor(RouteField field) =>
      field == RouteField.origin ? _originFocus : _destinationFocus;

  String get _activeSession =>
      _active == RouteField.origin ? _originSession : _destinationSession;

  /// Coordinates a search is measured against, so results come back nearest
  /// first: the user's device location, as inDrive does. When the device
  /// location is unavailable the chosen origin stands in for it.
  LatLng? get _searchContext {
    if (_deviceLocation != null) return _deviceLocation;
    if (_from != null) return LatLng(_from!.latitude, _from!.longitude);
    return widget.mapFallbackCenter;
  }

  Future<void> _loadSavedPlaces() async {
    final shortcuts = await widget.savedPlaces.shortcuts();
    final recents = await widget.savedPlaces.recents();
    if (!mounted) return;
    setState(() {
      _shortcuts = shortcuts;
      _recents = recents;
    });
  }

  /// Read the device location in the background so every search is ranked
  /// nearest-first around the user. Asks for the permission once when it was
  /// never decided; a declined permission is respected and the screen stays
  /// usable, just without distance ordering.
  Future<void> _primeDeviceLocation() async {
    try {
      var permission = await _locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
      }
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) return;

      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() => _deviceLocation = here);
      // The preview was built before the fix arrived, so move it now. A lite
      // map redraws rather than animates, so this is a move, not an animation.
      await _previewController?.moveCamera(
        CameraUpdate.newLatLngZoom(here, _previewZoom),
      );
    } catch (_) {
      // No location context; search still works, just without distances.
    }
  }

  // --- search --------------------------------------------------------------

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();

    // Editing after a selection invalidates it: the text no longer names a
    // point, so the caller must not receive stale coordinates.
    _clearActiveSelection();

    final query = value.trim();
    if (query.length < _minQueryLength) {
      _inFlight?.cancel();
      _sequence++;
      setState(() {
        _suggestions = const [];
        _mode = _ListMode.defaults;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounceTimer = Timer(_debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final sequence = ++_sequence;
    final field = _active;
    final cancelToken = CancelToken();
    _inFlight?.cancel();
    _inFlight = cancelToken;

    final context = _searchContext;

    try {
      final result = await _locationService.autocomplete(
        query: query,
        sessionToken: _activeSession,
        latitude: context?.latitude,
        longitude: context?.longitude,
        cancelToken: cancelToken,
      );

      // Drop the answer if a newer search started, the user switched fields, or
      // the text moved on while this was in flight.
      if (!mounted ||
          sequence != _sequence ||
          field != _active ||
          _activeController.text.trim() != query) {
        return;
      }

      setState(() {
        _suggestions = result.suggestions;
        _mode = result.suggestions.isEmpty
            ? _ListMode.empty
            : _ListMode.results;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (!mounted || sequence != _sequence || field != _active) return;
      setState(() {
        _suggestions = const [];
        _mode = e.response?.statusCode == 429
            ? _ListMode.rateLimited
            : _ListMode.error;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || sequence != _sequence || field != _active) return;
      setState(() {
        _suggestions = const [];
        _mode = _statusCodeOf(e) == 429
            ? _ListMode.rateLimited
            : _ListMode.error;
        _isLoading = false;
      });
    }
  }

  /// The app maps Dio errors to its own failure types, so recover the HTTP
  /// status from whatever shape arrives rather than assuming DioException.
  int? _statusCodeOf(Object error) {
    final text = error.toString();
    if (text.contains('429')) return 429;
    return null;
  }

  void _retrySearch() {
    final query = _activeController.text.trim();
    if (query.length < _minQueryLength) return;
    setState(() => _isLoading = true);
    _search(query);
  }

  // --- selection -----------------------------------------------------------

  void _clearActiveSelection() {
    if (_active == RouteField.origin) {
      if (_from != null) setState(() => _from = null);
    } else {
      if (_to != null) setState(() => _to = null);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _sequence++;
    setState(() => _isLoading = true);

    try {
      final location = await _locationService.placeDetail(
        placeId: suggestion.placeId,
        sessionToken: _activeSession,
      );
      if (!mounted) return;
      await _commitSelection(
        location,
        secondaryText: suggestion.secondaryText,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _mode = _ListMode.error;
      });
    }
  }

  /// Apply a confirmed choice to the active field, then follow inDrive's
  /// transition: origin hands focus to the destination, destination closes.
  Future<void> _commitSelection(
    LocationModel location, {
    String secondaryText = '',
  }) async {
    await widget.savedPlaces.addRecent(location, secondaryText: secondaryText);
    if (!mounted) return;

    // One field, one answer: confirming is the whole task, so close on it.
    if (widget.isSinglePoint) {
      _from = location;
      _originController.text = location.name;
      _originSession = const Uuid().v4();
      _finish();
      return;
    }

    if (_active == RouteField.origin) {
      _from = location;
      _originController.text = location.name;
      // A fresh session for the next search; a token is per selection.
      _originSession = const Uuid().v4();

      if (_to != null) {
        _finish();
        return;
      }

      setState(() {
        _active = RouteField.destination;
        _suggestions = const [];
        _mode = _ListMode.defaults;
        _isLoading = false;
      });
      _destinationFocus.requestFocus();
      _loadSavedPlaces();
      return;
    }

    _to = location;
    _destinationController.text = location.name;
    _destinationSession = const Uuid().v4();
    _finish();
  }

  void _finish() {
    Navigator.of(context).pop(RouteSelection(from: _from, to: _to));
  }

  Future<void> _openMapPicker() async {
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _sequence++;
    FocusScope.of(context).unfocus();

    final current = _active == RouteField.origin ? _from : _to;
    final l10n = context.l10n;
    final location = await Navigator.of(context).push<LocationModel>(
      MaterialPageRoute(
        builder: (_) => MapPointPickerScreen(
          confirmLabel: widget.isSinglePoint
              ? l10n.routeSearchConfirmPoint
              : (_active == RouteField.origin
                    ? l10n.routeSearchConfirmOrigin
                    : l10n.routeSearchConfirmDestination),
          initialLocation: current,
          fallbackCenter: _deviceLocation ?? widget.mapFallbackCenter,
        ),
      ),
    );

    if (location == null || !mounted) return;
    await _commitSelection(location);
  }

  void _switchTo(RouteField field) {
    if (_active == field) return;
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _sequence++;
    setState(() {
      _active = field;
      _suggestions = const [];
      _isLoading = false;
      _mode = _ListMode.defaults;
    });
    _focusNodeFor(field).requestFocus();
  }

  /// Exchange the two endpoints. Nothing is re-resolved: both sides already
  /// hold confirmed points (or nothing), so the swap is pure state.
  void _swapEndpoints() {
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _sequence++;
    setState(() {
      final location = _from;
      _from = _to;
      _to = location;

      final text = _originController.text;
      _originController.text = _destinationController.text;
      _destinationController.text = text;

      _suggestions = const [];
      _mode = _ListMode.defaults;
      _isLoading = false;
    });
  }

  void _clearActiveField() {
    _debounceTimer?.cancel();
    _inFlight?.cancel();
    _sequence++;
    _activeController.clear();
    _clearActiveSelection();
    setState(() {
      _suggestions = const [];
      _mode = _ListMode.defaults;
      _isLoading = false;
    });
    _focusNodeFor(_active).requestFocus();
  }

  Future<void> _useDeviceLocation() async {
    setState(() => _isLoading = true);
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      await _commitSelection(location);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.locationCurrentUnavailable)),
      );
    }
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back keeps whatever was already confirmed and drops any typed text
        // that was never turned into a point.
        _finish();
      },
      child: Scaffold(
        backgroundColor: T.background(context),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              SizedBox(
                height: 2,
                child: _isLoading
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: AppColors.transparent,
                        color: T.primary(context),
                      )
                    // Same height as the progress bar so nothing shifts when a
                    // search starts.
                    : const SizedBox.shrink(),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  /// A raised sheet holding the title and the route card, sitting above the
  /// map. The card keeps both endpoints in one enclosure joined by the A→B
  /// rail, so the pair reads as one route rather than two loose boxes.
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: T.surface(context),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Balances the close button so the title sits centred.
              const SizedBox(width: 52),
              Expanded(
                child: Text(
                  widget.singlePointTitle ?? context.l10n.routeSearchTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLarge.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: T.onSurface(context),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: _finish,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
            child: _buildRouteCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context) {
    final canSwap = _from != null || _to != null;

    final fields = Column(
      children: [
        _buildField(
          context,
          field: RouteField.origin,
          controller: _originController,
          focusNode: _originFocus,
          label: widget.singlePointTitle ?? context.l10n.fromLabel,
          hint: widget.singlePointHint ?? context.l10n.routeSearchFromHint,
          dotColor: T.success(context),
          isFirst: true,
          isLast: widget.isSinglePoint,
        ),
        if (!widget.isSinglePoint) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 46, end: 12),
            child: Divider(height: 1, color: T.outlineVariant(context)),
          ),
          _buildField(
            context,
            field: RouteField.destination,
            controller: _destinationController,
            focusNode: _destinationFocus,
            label: context.l10n.toLabel,
            hint: context.l10n.routeSearchToHint,
            dotColor: T.error(context),
            isFirst: false,
            isLast: true,
          ),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: T.surfaceVariant(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.outlineVariant(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: fields),
            if (!widget.isSinglePoint)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert_rounded),
                  iconSize: 22,
                  color: canSwap
                      ? T.primary(context)
                      : T.outlineVariant(context),
                  tooltip: context.l10n.routeSearchSwap,
                  onPressed: canSwap ? _swapEndpoints : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The open circle inDrive uses for a route endpoint: green for A, red for B.
  Widget _buildDot(Color color) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3.5),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required RouteField field,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required Color dotColor,
    required bool isFirst,
    required bool isLast,
  }) {
    final isActive = _active == field;
    // The label only earns its line once the field holds a place: an empty
    // field says what it wants through its hint instead.
    final showLabel = !isActive && controller.text.trim().isNotEmpty;
    final radius = Radius.circular(isActive ? 18 : 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: isActive ? T.surface(context) : AppColors.transparent,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? radius : Radius.zero,
          bottom: isLast ? radius : Radius.zero,
        ),
      ),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Center(
              child: isActive
                  ? Icon(Icons.search, size: 20, color: T.primary(context))
                  : _buildDot(dotColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showLabel)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      label,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        color: T.onSurfaceVariant(context),
                      ),
                    ),
                  ),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onTap: () => _switchTo(field),
                  onChanged: isActive ? _onQueryChanged : null,
                  textInputAction: TextInputAction.search,
                  // Enter only dismisses the keyboard. It must never pick a
                  // place, so text and suggestions can never disagree.
                  onSubmitted: (_) => focusNode.unfocus(),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: T.onSurface(context),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      color: T.onSurfaceVariant(context),
                    ),
                    contentPadding: EdgeInsets.only(
                      top: showLabel ? 2 : 16,
                      bottom: showLabel ? 11 : 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isActive && controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cancel, size: 20),
              color: T.onSurfaceVariant(context),
              tooltip: context.l10n.routeSearchClearField,
              visualDensity: VisualDensity.compact,
              onPressed: _clearActiveField,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_mode) {
      case _ListMode.results:
        return _buildResults(context);
      case _ListMode.defaults:
        return _buildDefaults(context);
      case _ListMode.empty:
        return _buildMessage(
          context,
          icon: Icons.search_off,
          message: context.l10n.routeSearchNoResults,
        );
      case _ListMode.rateLimited:
        return _buildMessage(
          context,
          icon: Icons.hourglass_empty,
          message: context.l10n.routeSearchTooManyRequests,
          onRetry: _retrySearch,
        );
      case _ListMode.error:
        return _buildMessage(
          context,
          icon: Icons.cloud_off,
          message: context.l10n.routeSearchFailed,
          onRetry: _retrySearch,
        );
    }
  }

  /// Shown before the user types: the two shortcuts as buttons, the saved and
  /// recent places, then a live map filling whatever room is left — so the
  /// screen opens on something to act on rather than on empty white.
  Widget _buildDefaults(BuildContext context) {
    final places = <Widget>[
      if (_shortcuts.isNotEmpty) ...[
        _buildSectionLabel(context, context.l10n.routeSearchSaved),
        ..._shortcuts.map(
          (place) => PlaceResultRow(
            icon: _shortcutIcon(place.kind),
            title: place.label.isNotEmpty ? place.label : place.name,
            subtitle: place.label.isNotEmpty ? place.name : place.secondaryText,
            onTap: () => _commitSelection(
              place.toLocation(),
              secondaryText: place.secondaryText,
            ),
          ),
        ),
      ],
      if (_recents.isNotEmpty) ...[
        _buildSectionLabel(
          context,
          context.l10n.routeSearchRecents,
          action: TextButton(
            onPressed: () async {
              await widget.savedPlaces.clearRecents();
              await _loadSavedPlaces();
            },
            child: Text(context.l10n.routeSearchClearRecents),
          ),
        ),
        ..._recents.map(
          (place) => PlaceResultRow(
            icon: Icons.history,
            title: place.name,
            subtitle: place.secondaryText,
            onTap: () => _commitSelection(
              place.toLocation(),
              secondaryText: place.secondaryText,
            ),
          ),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // The saved places never take more than their share: the map has to
        // stay the biggest thing on an otherwise idle screen.
        final listCap = constraints.maxHeight * 0.42;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: _buildQuickActions(context),
            ),
            if (places.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listCap),
                child: ListView(
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  children: places,
                ),
              ),
            Expanded(child: _buildMapPreview(context)),
          ],
        );
      },
    );
  }

  /// The two things that are actions rather than places, as side-by-side
  /// buttons instead of list rows that read like results.
  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionChip(
            context,
            icon: Icons.my_location_rounded,
            label: context.l10n.routeSearchCurrentLocation,
            onTap: _useDeviceLocation,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionChip(
            context,
            icon: Icons.map_outlined,
            label: context.l10n.routeSearchPickOnMap,
            onTap: _openMapPicker,
          ),
        ),
      ],
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final primary = T.primary(context);
    return Material(
      color: primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A live map of where the user is, filling the idle space. It is a preview,
  /// not a picker: tapping anywhere opens the full picker on the same view, so
  /// there is exactly one place where a point is confirmed.
  Widget _buildMapPreview(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Too little room left (keyboard up, long recents list) — a squashed
        // map is worse than none, and the chip above still opens the picker.
        if (constraints.maxHeight < 140) return const SizedBox.shrink();

        final center = _previewCenter;
        final markers = <Marker>{
          if (_from != null)
            Marker(
              markerId: const MarkerId('from'),
              position: LatLng(_from!.latitude, _from!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
          if (_to != null)
            Marker(
              markerId: const MarkerId('to'),
              position: LatLng(_to!.latitude, _to!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
        };

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: _deviceLocation == null ? 11 : _previewZoom,
                  ),
                  onMapCreated: (controller) =>
                      _previewController = controller,
                  markers: markers,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  liteModeEnabled: true,
                  // Every gesture belongs to the tap that opens the picker.
                  zoomGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
                Positioned.fill(
                  child: Material(
                    color: AppColors.transparent,
                    child: InkWell(onTap: _openMapPicker),
                  ),
                ),
                // Marks the map as something that opens, without repeating
                // the wording of the button above it.
                PositionedDirectional(
                  end: 12,
                  bottom: 12,
                  child: IgnorePointer(child: _buildMapPreviewBadge(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapPreviewBadge(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: T.surface(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: T.shadow(context).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.zoom_out_map_rounded,
        size: 20,
        color: T.primary(context),
      ),
    );
  }

  IconData _shortcutIcon(SavedPlaceKind kind) {
    switch (kind) {
      case SavedPlaceKind.home:
        return Icons.home_outlined;
      case SavedPlaceKind.work:
        return Icons.work_outline;
      default:
        return Icons.star_outline;
    }
  }

  Widget _buildResults(BuildContext context) {
    // Marked against the live text so the highlight follows what is typed,
    // not the query the results were fetched for.
    final query = _activeController.text.trim();

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: _suggestions.length + 1,
      itemBuilder: (context, index) {
        // inDrive keeps the map option pinned above the results, so a place
        // the provider cannot name is always one tap away.
        if (index == 0) {
          return _buildActionRow(
            context,
            icon: Icons.person_pin_circle_outlined,
            title: context.l10n.routeSearchPickOnMap,
            onTap: _openMapPicker,
          );
        }

        final suggestion = _suggestions[index - 1];
        return PlaceResultRow(
          icon: Icons.location_on_outlined,
          title: suggestion.primaryText.isNotEmpty
              ? suggestion.primaryText
              : suggestion.description,
          subtitle: suggestion.secondaryText,
          query: query,
          trailing: _formatDistance(context, suggestion.distanceMeters),
          onTap: () => _selectSuggestion(suggestion),
        );
      },
    );
  }

  /// Approximate straight-line distance, not driving time.
  String? _formatDistance(BuildContext context, int? meters) {
    if (meters == null) return null;
    if (meters < 1000) {
      return context.l10n.distanceMetersShort('$meters');
    }
    final km = meters / 1000;
    return context.l10n.distanceKmShort(
      km >= 10 ? km.toStringAsFixed(0) : km.toStringAsFixed(1),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String label, {
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, top: 16, end: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: T.onSurfaceVariant(context),
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    // Accent-coloured and icon-led, the way inDrive marks the two shortcuts
    // that are actions rather than places.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 22, color: T.primary(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: T.primary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String message,
    VoidCallback? onRetry,
  }) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        Icon(icon, size: 40, color: T.onSurfaceVariant(context)),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: T.onSurfaceVariant(context),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.routeSearchRetry),
            ),
          ),
        ],
        const SizedBox(height: 8),
        // Picking on the map always stays reachable, so a provider outage never
        // blocks the user from setting a point.
        Center(
          child: TextButton.icon(
            onPressed: _openMapPicker,
            icon: const Icon(Icons.map_outlined),
            label: Text(context.l10n.routeSearchPickOnMap),
          ),
        ),
      ],
    );
  }
}
