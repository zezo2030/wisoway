import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A place Google draws on the map itself (a restaurant, a school...) that
/// the user tapped.
class PoiTap {
  const PoiTap({
    required this.placeId,
    required this.name,
    required this.position,
  });

  final String placeId;
  final String name;
  final LatLng position;
}

/// Reports taps on Google's own places for one map.
///
/// `google_maps_flutter` has no such event, so the app ships patched copies of
/// its Android and iOS implementations (see `dependency_overrides` in
/// pubspec.yaml) that send each tap on `wisoway/poi_tap_<mapId>`. On any other
/// platform nothing is ever sent and [onTap] simply never fires.
class PoiTapListener {
  PoiTapListener(int mapId, this.onTap)
    : _channel = MethodChannel('wisoway/poi_tap_$mapId') {
    _channel.setMethodCallHandler(_handle);
  }

  final MethodChannel _channel;
  final void Function(PoiTap tap) onTap;

  Future<void> _handle(MethodCall call) async {
    if (call.method != 'poiTap') return;
    final args = Map<String, dynamic>.from(call.arguments as Map);
    final lat = (args['latitude'] as num?)?.toDouble();
    final lng = (args['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    onTap(
      PoiTap(
        placeId: args['placeId'] as String? ?? '',
        // Google sometimes puts the category on a second line.
        name: (args['name'] as String? ?? '').split('\n').first.trim(),
        position: LatLng(lat, lng),
      ),
    );
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
