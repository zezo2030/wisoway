class LocationModel {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  LocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  // Create from Map
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      name: map['name'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'],
    );
  }

  /// Create from a StopDto-shaped map (backend uses lat/lng instead of latitude/longitude).
  factory LocationModel.fromStopMap(Map<String, dynamic> map) {
    return LocationModel(
      name: map['name'] ?? '',
      latitude: ((map['lat'] ?? map['latitude']) ?? 0.0).toDouble(),
      longitude: ((map['lng'] ?? map['longitude']) ?? 0.0).toDouble(),
      address: map['address'],
    );
  }

  /// Serialize as a StopDto (lat/lng keys, with order).
  Map<String, dynamic> toStopMap({required int order}) {
    return {
      'name': name,
      'lat': latitude,
      'lng': longitude,
      if (address != null) 'address': address,
      'order': order,
    };
  }

  // Create a copy with updated fields
  LocationModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? address,
  }) {
    return LocationModel(
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
    );
  }
}

