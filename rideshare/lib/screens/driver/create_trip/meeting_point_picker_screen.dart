import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../l10n/l10n_extensions.dart';
import '../../../models/trip_meeting_point.dart';

/// Full-screen map for pinning a trip's exact meeting point.
///
/// The pin stays fixed in the centre and the map moves under it — the usual
/// way to place a point precisely with a thumb. The address under the pin is
/// looked up once the map settles. Pops the chosen [TripMeetingPoint] (without
/// a note; the driver writes that on the route step).
class MeetingPointPickerScreen extends StatefulWidget {
  const MeetingPointPickerScreen({super.key, required this.initialTarget});

  /// Where the map opens: the current pin, or else the trip's origin.
  final LatLng initialTarget;

  @override
  State<MeetingPointPickerScreen> createState() =>
      _MeetingPointPickerScreenState();
}

class _MeetingPointPickerScreenState extends State<MeetingPointPickerScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _controller;
  late LatLng _target = widget.initialTarget;
  String? _address;
  bool _resolving = false;
  CancelToken? _lookup;

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  @override
  void dispose() {
    _lookup?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress() async {
    _lookup?.cancel();
    final token = CancelToken();
    _lookup = token;
    setState(() => _resolving = true);
    try {
      final result = await _locationService.reverseGeocode(
        latitude: _target.latitude,
        longitude: _target.longitude,
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _address = result.label.isNotEmpty ? result.label : null;
        _resolving = false;
      });
    } catch (_) {
      if (!mounted || token.isCancelled) return;
      setState(() => _resolving = false);
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17),
      );
    } catch (_) {
      // Location off — the driver can still pan to the spot.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingPointPickerTitle)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _target, zoom: 17),
            onMapCreated: (c) => _controller = c,
            onCameraMove: (p) => _target = p.target,
            onCameraIdle: _resolveAddress,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          // The pin's tip marks the centre, so lift the icon by half its size.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: T.primary(context),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: T.surface(context),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: T.shadow(context).withValues(alpha: 0.12),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                l10n.meetingPointPickerHint,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: T.onSurface(context),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 16,
            bottom: 170,
            child: FloatingActionButton.small(
              heroTag: 'meeting-point-my-location',
              backgroundColor: T.surface(context),
              foregroundColor: T.onSurface(context),
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: T.surface(context),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: T.shadow(context).withValues(alpha: 0.14),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place_outlined, color: T.primary(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _resolving
                                ? l10n.meetingPointLocating
                                : (_address ?? '—'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: T.onSurface(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(
                          context,
                          TripMeetingPoint(
                            latitude: _target.latitude,
                            longitude: _target.longitude,
                            address: _address,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: T.primary(context),
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.meetingPointConfirm,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
