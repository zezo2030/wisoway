enum PassengerPresenceStatus {
  inVehicle('in_vehicle'),
  onMyWay('on_my_way'),
  notRiding('not_riding');

  const PassengerPresenceStatus(this.wireValue);

  final String wireValue;

  static PassengerPresenceStatus? fromWireValue(String? wireValue) {
    for (final status in values) {
      if (status.wireValue == wireValue) return status;
    }
    return null;
  }
}

class PresenceDriver {
  const PresenceDriver({
    required this.id,
    required this.name,
    this.photoUrl,
    this.rating,
    required this.ratingCount,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final double? rating;
  final int ratingCount;

  factory PresenceDriver.fromJson(Map<String, dynamic> json) {
    return PresenceDriver(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      rating: _doubleOrNull(json['rating']),
      ratingCount: _intOrZero(json['ratingCount']),
    );
  }
}

class PresenceVehicle {
  const PresenceVehicle({
    required this.vehicleType,
    required this.model,
    required this.plateNumber,
    this.carImageUrl,
  });

  final String vehicleType;
  final String model;
  final String plateNumber;
  final String? carImageUrl;

  factory PresenceVehicle.fromJson(Map<String, dynamic> json) {
    return PresenceVehicle(
      vehicleType: json['vehicleType']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      plateNumber: json['plateNumber']?.toString() ?? '',
      carImageUrl: json['carImageUrl']?.toString(),
    );
  }
}

class PresencePoint {
  const PresencePoint({
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PresencePoint.fromJson(Map<String, dynamic> json) {
    return PresencePoint(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      latitude: _doubleOrNull(json['lat']),
      longitude: _doubleOrNull(json['lng']),
    );
  }
}

class PresenceDriverLocation {
  const PresenceDriverLocation({
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  factory PresenceDriverLocation.fromJson(Map<String, dynamic> json) {
    return PresenceDriverLocation(
      latitude: _doubleOrNull(json['lat']) ?? 0,
      longitude: _doubleOrNull(json['lng']) ?? 0,
      updatedAt: _dateOrNull(json['updatedAt']),
    );
  }
}

class PresencePromptSeat {
  const PresencePromptSeat({
    required this.seatNumber,
    required this.displayName,
    required this.isMainBooker,
    this.declaredStatus,
    this.selfConfirmedAt,
  });

  final String seatNumber;
  final String displayName;
  final bool isMainBooker;
  final PassengerPresenceStatus? declaredStatus;
  final DateTime? selfConfirmedAt;

  factory PresencePromptSeat.fromJson(Map<String, dynamic> json) {
    return PresencePromptSeat(
      seatNumber: json['seatNumber']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      isMainBooker: json['isMainBooker'] == true,
      declaredStatus: PassengerPresenceStatus.fromWireValue(
        json['declaredStatus']?.toString(),
      ),
      selfConfirmedAt: _dateOrNull(json['selfConfirmedAt']),
    );
  }
}

class PresenceWindow {
  const PresenceWindow({
    required this.opensAt,
    required this.closesAt,
    required this.isOpen,
  });

  final DateTime opensAt;
  final DateTime closesAt;
  final bool isOpen;

  factory PresenceWindow.fromJson(Map<String, dynamic> json) {
    return PresenceWindow(
      opensAt: _dateOrNow(json['opensAt']),
      closesAt: _dateOrNow(json['closesAt']),
      isOpen: json['isOpen'] == true,
    );
  }
}

class PresencePrompt {
  const PresencePrompt({
    required this.bookingId,
    required this.tripId,
    required this.driver,
    required this.vehicle,
    required this.pickup,
    required this.departureTime,
    required this.secondsUntilDeparture,
    required this.seats,
    required this.window,
    this.driverLocation,
  });

  final String bookingId;
  final String tripId;
  final PresenceDriver? driver;
  final PresenceVehicle? vehicle;
  final PresencePoint pickup;
  final DateTime departureTime;
  final int secondsUntilDeparture;
  final List<PresencePromptSeat> seats;
  final PresenceWindow window;
  final PresenceDriverLocation? driverLocation;

  PassengerPresenceStatus? get declaredStatus {
    if (seats.isEmpty) return null;
    final firstStatus = seats.first.declaredStatus;
    return seats.every((seat) => seat.declaredStatus == firstStatus)
        ? firstStatus
        : null;
  }

  factory PresencePrompt.fromJson(Map<String, dynamic> json) {
    final rawDriverLocation = json['driverLocation'];
    return PresencePrompt(
      bookingId: json['bookingId']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      driver: _optionalMap(json['driver'], PresenceDriver.fromJson),
      vehicle: _optionalMap(json['vehicle'], PresenceVehicle.fromJson),
      pickup: PresencePoint.fromJson(_mapOrEmpty(json['pickup'])),
      departureTime: _dateOrNow(json['departureTime']),
      secondsUntilDeparture: _intOrZero(json['secondsUntilDeparture']),
      seats: _mapList(json['seats']).map(PresencePromptSeat.fromJson).toList(),
      window: PresenceWindow.fromJson(_mapOrEmpty(json['window'])),
      driverLocation: rawDriverLocation is Map
          ? PresenceDriverLocation.fromJson(_mapOrEmpty(rawDriverLocation))
          : null,
    );
  }
}

Map<String, dynamic> _mapOrEmpty(dynamic rawMap) {
  if (rawMap is Map<String, dynamic>) return rawMap;
  if (rawMap is Map) return Map<String, dynamic>.from(rawMap);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic rawList) {
  if (rawList is! List) return const [];
  return rawList.map(_mapOrEmpty).toList();
}

T? _optionalMap<T>(dynamic rawMap, T Function(Map<String, dynamic>) parse) {
  if (rawMap == null) return null;
  return parse(_mapOrEmpty(rawMap));
}

double? _doubleOrNull(dynamic rawNumber) {
  if (rawNumber is num) return rawNumber.toDouble();
  return double.tryParse(rawNumber?.toString() ?? '');
}

int _intOrZero(dynamic rawNumber) {
  if (rawNumber is num) return rawNumber.toInt();
  return int.tryParse(rawNumber?.toString() ?? '') ?? 0;
}

DateTime? _dateOrNull(dynamic rawDate) {
  if (rawDate is DateTime) return rawDate;
  return DateTime.tryParse(rawDate?.toString() ?? '');
}

DateTime _dateOrNow(dynamic rawDate) => _dateOrNull(rawDate) ?? DateTime.now();
