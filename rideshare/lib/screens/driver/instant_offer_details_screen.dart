import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/services/instant_ride_service.dart';
import '../../core/theme/colors.dart';
import '../../core/ui/error_surface.dart';
import '../../l10n/l10n_extensions.dart';
import '../../models/instant_ride_models.dart';
import '../passenger/trip_details_screen.dart';
import 'widgets/instant_fare_editor.dart';
import 'widgets/instant_offer_parts.dart';

/// How the driver left the offer. The compact card that launched this screen
/// uses it to dismiss itself instead of hanging over a decision already made.
enum InstantOfferOutcome { accepted, declined, countered, expired }

/// The full request behind an instant-ride offer: the whole route, both legs
/// of distance, who is asking, and the three things a driver can do about it —
/// take it at the passenger's price, name a higher one, or pass.
///
/// The interrupting card deliberately shows less; this is where a driver comes
/// to actually read the job before committing to it.
class InstantOfferDetailsScreen extends StatefulWidget {
  final InstantOffer offer;
  final InstantRideService service;

  /// Opens the counter composer immediately, for the "اقترح سعرًا أعلى"
  /// shortcut on the card.
  final bool startCountering;

  const InstantOfferDetailsScreen({
    super.key,
    required this.offer,
    required this.service,
    this.startCountering = false,
  });

  @override
  State<InstantOfferDetailsScreen> createState() =>
      _InstantOfferDetailsScreenState();
}

class _InstantOfferDetailsScreenState extends State<InstantOfferDetailsScreen> {
  late final TextEditingController _counterController;
  late int _secondsLeft;
  late final int _totalSeconds;
  Timer? _ticker;
  bool _busy = false;
  bool _countering = false;
  double? _counterAmount;
  GoogleMapController? _mapController;

  InstantRequestSummary? get _req => widget.offer.request;

  double? get _passengerFare => _req?.passengerFareValue;

  /// The server caps a counter at +50% of the passenger's fare; going past it
  /// only earns a rejected request, so the editor never offers the value.
  double get _counterMax {
    final fare = _passengerFare ?? 0;
    return (fare * 1.5 * 100).floorToDouble() / 100;
  }

  double get _counterMin {
    final fare = _passengerFare ?? 0;
    return ((fare + fareStepFor(fare)) * 100).roundToDouble() / 100;
  }

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.offer.expiresAt;
    final remaining = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inSeconds
        : 25;
    _secondsLeft = remaining.clamp(1, 120);
    _totalSeconds = _secondsLeft;
    _counterController = TextEditingController(
      text: _passengerFare == null ? '' : _counterMin.toStringAsFixed(2),
    );
    _counterAmount = _passengerFare == null ? null : _counterMin;
    _countering = widget.startCountering && _passengerFare != null;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft -= 1);
      if (_secondsLeft <= 0) {
        _ticker?.cancel();
        Navigator.of(context).pop(InstantOfferOutcome.expired);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _counterController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final request = await widget.service.acceptOffer(widget.offer.id);
      _ticker?.cancel();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final toast = context.l10n.instantRideAcceptedToast;
      navigator.pop(InstantOfferOutcome.accepted);
      messenger.showSnackBar(
        SnackBar(content: Text(toast), backgroundColor: AppColors.success),
      );
      final tripId = request.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(builder: (_) => TripDetailsScreen(tripId: tripId)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.declineOffer(widget.offer.id);
    } catch (_) {
      // The offer may already be gone; leaving is the right outcome either way.
    }
    _ticker?.cancel();
    if (mounted) Navigator.of(context).pop(InstantOfferOutcome.declined);
  }

  Future<void> _sendCounter() async {
    final amount = _counterAmount;
    if (_busy || amount == null) return;
    if (amount < _counterMin || amount > _counterMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.instantCounterRangeHint(
              _counterMin.toStringAsFixed(2),
              _counterMax.toStringAsFixed(2),
              _req?.currency ?? '',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.counterOffer(widget.offer.id, amount);
      _ticker?.cancel();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final toast = context.l10n.instantCounterSentToast;
      Navigator.of(context).pop(InstantOfferOutcome.countered);
      messenger.showSnackBar(
        SnackBar(content: Text(toast), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ErrorSurface.showFailure(context, ApiClient.mapError(e));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final req = _req;

    return Scaffold(
      backgroundColor: T.background(context),
      appBar: AppBar(
        title: Text(l10n.instantOfferDetailsTitle),
        centerTitle: true,
        backgroundColor: T.surface(context),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                children: [
                  InstantSectionCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: InstantCountdownBar(
                      secondsLeft: _secondsLeft,
                      totalSeconds: _totalSeconds,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fareCard(context, req),
                  const SizedBox(height: 12),
                  _mapCard(req),
                  const SizedBox(height: 12),
                  InstantSectionCard(
                    child: InstantRouteBlock(
                      fromName: req?.fromName ?? '—',
                      toName: req?.toName ?? '—',
                      fromAddress: req?.fromAddress,
                      toAddress: req?.toAddress,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _metricsCard(context, req),
                  const SizedBox(height: 12),
                  InstantSectionCard(
                    child: InstantPassengerRow(
                      name: req?.passengerName,
                      rating: req?.passengerRating,
                      totalRatings: req?.passengerTotalRatings,
                      photoUrl: req?.passengerPhotoUrl,
                      seatsLabel:
                          req?.seatCountLabel ??
                          l10n.instantOfferPassengerCount(req?.seatCount ?? 1),
                    ),
                  ),
                ],
              ),
            ),
            _actionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _fareCard(BuildContext context, InstantRequestSummary? req) {
    final l10n = context.l10n;
    final fare = req?.passengerFare ?? req?.fareEstimate;
    final earnings =
        req?.earningsLabel ??
        (fare != null ? '$fare ${req?.currency ?? ''}' : '—');
    return InstantSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: InstantFareHero(
              earnings: earnings,
              label: l10n.instantOfferExpectedEarnings,
              note: l10n.instantOfferCashNote,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: T.primaryContainer(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              req?.tripTypeLabel ?? l10n.instantOfferBadge,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: T.onPrimaryContainer(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsCard(BuildContext context, InstantRequestSummary? req) {
    final l10n = context.l10n;
    final pickupDistance = req?.pickupDistanceLabel;
    final pickupEta = req?.pickupEtaMinutes;
    final tiles = <Widget>[
      // The driver's own leg comes first: it is the cost of taking the job.
      InstantMetricTile(
        icon: Icons.my_location,
        label: l10n.instantOfferPickupDistance,
        value: pickupDistance ?? '—',
        emphasized: true,
      ),
      InstantMetricTile(
        icon: Icons.timer_outlined,
        label: l10n.instantOfferPickupEta,
        value: pickupEta != null
            ? l10n.instantSearchingMinutes(pickupEta.toString())
            : '—',
        emphasized: true,
      ),
      InstantMetricTile(
        icon: Icons.route_outlined,
        label: l10n.instantOfferTripDistance,
        value: req?.distanceLabel ?? '—',
      ),
      InstantMetricTile(
        icon: Icons.schedule,
        label: l10n.instantOfferDuration,
        value: req?.durationLabel ?? '—',
      ),
    ];

    return InstantSectionCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: 12),
              Expanded(child: tiles[3]),
            ],
          ),
        ],
      ),
    );
  }

  /// A static look at the two ends of the trip. Lite mode keeps it cheap: this
  /// map is here to be read at a glance, never panned.
  Widget _mapCard(InstantRequestSummary? req) {
    final pickupLat = req?.pickupLat;
    final pickupLng = req?.pickupLng;
    if (pickupLat == null || pickupLng == null) {
      return const SizedBox.shrink();
    }
    final pickup = LatLng(pickupLat, pickupLng);
    final dropLat = req?.dropoffLat;
    final dropLng = req?.dropoffLng;
    final dropoff = (dropLat != null && dropLng != null)
        ? LatLng(dropLat, dropLng)
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 170,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: pickup, zoom: 12),
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('offer_pickup'),
              position: pickup,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
            ),
            if (dropoff != null)
              Marker(
                markerId: const MarkerId('offer_dropoff'),
                position: dropoff,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
          },
          polylines: {
            if (dropoff != null)
              Polyline(
                polylineId: const PolylineId('offer_route'),
                points: [pickup, dropoff],
                width: 4,
                color: T.primary(context),
              ),
          },
          onMapCreated: (controller) {
            _mapController = controller;
            if (dropoff == null) return;
            controller.moveCamera(
              CameraUpdate.newLatLngBounds(_boundsFor(pickup, dropoff), 46),
            );
          },
        ),
      ),
    );
  }

  LatLngBounds _boundsFor(LatLng a, LatLng b) {
    return LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    final l10n = context.l10n;
    final canCounter = _passengerFare != null && _counterMax > _counterMin;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: T.surface(context),
        border: Border(top: BorderSide(color: T.outlineVariant(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_countering) ...[
            InstantFareEditor(
              controller: _counterController,
              min: _counterMin,
              max: _counterMax,
              currency: _req?.currency ?? '',
              enabled: !_busy,
              onChanged: (value) => setState(() => _counterAmount = value),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : (_countering
                              ? () => setState(() => _countering = false)
                              : _decline),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.onSurface(context),
                      side: BorderSide(color: T.outlineVariant(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _countering ? l10n.cancel : l10n.instantOfferIgnore,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : (_countering ? _sendCounter : _accept),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.primary(context),
                      foregroundColor: T.onPrimary(context),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                T.onPrimary(context),
                              ),
                            ),
                          )
                        : Text(
                            _countering
                                ? l10n.instantSendOffer
                                : l10n.instantOfferAcceptTrip,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (!_countering && canCounter) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _countering = true),
              icon: const Icon(Icons.trending_up, size: 19),
              label: Text(l10n.instantProposeFare),
              style: TextButton.styleFrom(foregroundColor: T.primary(context)),
            ),
          ],
        ],
      ),
    );
  }
}
