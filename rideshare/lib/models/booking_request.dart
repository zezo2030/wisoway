import '../core/utils/backend_url_resolver.dart';
import '../utils/seat_layout_helpers.dart';
import 'seat_layout_config.dart';

/// One seat in a booking request: its seat-map number and who sits there.
class BookingRequestSeat {
  final String number;
  final String? name;
  final bool isCompanion;

  const BookingRequestSeat({
    required this.number,
    this.name,
    this.isCompanion = false,
  });
}

/// A booking on one of the driver's shared trips that is still waiting for the
/// driver to accept or decline it (`GET /v2/bookings/pending-requests`).
class BookingRequest {
  final String id;
  final String tripId;
  final int seatCount;
  final double? totalAmount;
  final String currency;
  final bool isFamilyBooking;
  final DateTime? expiresAt;
  final DateTime createdAt;

  final String? passengerName;
  final String? passengerPhotoUrl;
  final String? passengerGender;
  final double? passengerRating;

  final String fromName;
  final String toName;
  final DateTime? departureTime;

  /// Seats in this request, as numbered on the seat map.
  final List<BookingRequestSeat> seats;

  const BookingRequest({
    required this.id,
    required this.tripId,
    required this.seatCount,
    required this.currency,
    required this.createdAt,
    required this.fromName,
    required this.toName,
    this.totalAmount,
    this.isFamilyBooking = false,
    this.expiresAt,
    this.passengerName,
    this.passengerPhotoUrl,
    this.passengerGender,
    this.passengerRating,
    this.departureTime,
    this.seats = const [],
  });

  static double? _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    final passenger = json['passenger'] is Map
        ? Map<String, dynamic>.from(json['passenger'] as Map)
        : const <String, dynamic>{};
    final trip = json['trip'] is Map
        ? Map<String, dynamic>.from(json['trip'] as Map)
        : const <String, dynamic>{};
    final layoutMap = trip['seatLayout'] is Map
        ? Map<String, dynamic>.from(trip['seatLayout'] as Map)
        : null;
    final layout = layoutMap == null
        ? null
        : SeatLayoutConfig.fromMap(layoutMap);
    String seatNumber(String id) {
      final coords = SeatLayoutHelpers.parseBackendSeatId(id);
      if (layout == null || coords == null) return id;
      return SeatLayoutHelpers.backendCoordsToDisplayIndex(
            layout,
            coords.row,
            coords.col,
          )?.toString() ??
          id;
    }

    final seats = (json['seats'] as List? ?? const [])
        .whereType<Map>()
        .map((s) {
          final name = s['displayName']?.toString().trim();
          return BookingRequestSeat(
            number: seatNumber(s['seatNumber']?.toString() ?? ''),
            name: name == null || name.isEmpty ? null : name,
            isCompanion: s['isMainBooker'] == false,
          );
        })
        .toList();

    return BookingRequest(
      seats: seats,
      id: json['id']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      seatCount: _num(json['seatCount'])?.toInt() ?? 1,
      totalAmount: _num(json['totalAmount']),
      currency: json['currency']?.toString() ?? 'JOD',
      isFamilyBooking: json['isFamilyBooking'] == true,
      expiresAt: _date(json['expiresAt']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      passengerName: passenger['name']?.toString(),
      passengerPhotoUrl: BackendUrlResolver.normalize(
        passenger['photoUrl']?.toString(),
      ),
      passengerGender: passenger['gender']?.toString(),
      passengerRating: _num(passenger['rating']),
      fromName: trip['fromName']?.toString() ?? '—',
      toName: trip['toName']?.toString() ?? '—',
      departureTime: _date(trip['departureTime']),
    );
  }
}
