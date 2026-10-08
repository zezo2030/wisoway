import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/colors.dart';
import '../l10n/l10n_extensions.dart';
import '../models/trip_meeting_point.dart';

/// Where a shared trip gathers: the driver's description, the address, a map
/// of the exact pin, and a hand-off to the phone's maps app for directions.
class MeetingPointCard extends StatelessWidget {
  const MeetingPointCard({
    super.key,
    required this.meetingPoint,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final TripMeetingPoint meetingPoint;
  final EdgeInsetsGeometry margin;

  Future<void> _openInMaps() async {
    final lat = meetingPoint.latitude;
    final lng = meetingPoint.longitude;
    await launchUrl(
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final point = LatLng(meetingPoint.latitude, meetingPoint.longitude);
    final note = meetingPoint.note;
    final address = meetingPoint.address;

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: T.primary(context), size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.meetingPointCardTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 10),
              Text(
                note,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: T.onSurface(context),
                  height: 1.4,
                ),
              ),
            ],
            if (address != null) ...[
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  fontSize: 13,
                  color: T.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: point, zoom: 16),
                  markers: {
                    Marker(markerId: const MarkerId('meeting'), position: point),
                  },
                  liteModeEnabled: true,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: (_) => _openInMaps(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _openInMaps,
                icon: const Icon(Icons.directions_outlined),
                label: Text(l10n.meetingPointOpenInMaps),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
