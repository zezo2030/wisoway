/// The exact spot a shared trip gathers at: a map pin, the address it resolves
/// to, and the driver's own description ("by the roundabout, in front of the
/// pharmacy"). Null on trips created before the field existed.
class TripMeetingPoint {
  final double latitude;
  final double longitude;
  final String? address;
  final String? note;

  const TripMeetingPoint({
    required this.latitude,
    required this.longitude,
    this.address,
    this.note,
  });

  TripMeetingPoint copyWith({String? address, String? note}) =>
      TripMeetingPoint(
        latitude: latitude,
        longitude: longitude,
        address: address ?? this.address,
        note: note ?? this.note,
      );

  static TripMeetingPoint? fromJson(dynamic json) {
    if (json is! Map) return null;
    double? n(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    final lat = n(json['lat']);
    final lng = n(json['lng']);
    if (lat == null || lng == null) return null;
    String? text(dynamic v) {
      final t = v?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    return TripMeetingPoint(
      latitude: lat,
      longitude: lng,
      address: text(json['address']),
      note: text(json['note']),
    );
  }

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    if (address != null && address!.isNotEmpty) 'address': address,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}
