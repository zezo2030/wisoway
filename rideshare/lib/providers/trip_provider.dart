import 'package:flutter/widgets.dart';
import 'dart:io';
import '../core/services/trip_service.dart';
import '../core/api/api_client.dart';
import '../core/errors/failure.dart';
import '../core/api/websocket_service.dart';
import '../models/trip_model.dart';
import 'dart:async';
import '../models/location_model.dart';
import '../models/trip_meeting_point.dart';

class TripProvider extends ChangeNotifier {
  final TripService _tripService = TripService();
  final WebSocketService _socket = WebSocketService();

  bool _isLoading = false;
  String? _errorMessage;
  List<TripModel> _driverTrips = [];
  List<TripModel> _activeTrips = [];

  final _driverTripsController = StreamController<List<TripModel>>.broadcast();
  final _activeTripsController = StreamController<List<TripModel>>.broadcast();
  final Set<String> _loadedDriverTripsKeys = <String>{};
  final Set<String> _loadedActiveTripsKeys = <String>{};

  List<TripModel> _nearbyTrips = [];
  final _nearbyTripsController = StreamController<List<TripModel>>.broadcast();
  String? _nearbyKey;
  ({
    LocationModel location,
    String excludeDriverId,
    double radiusKm,
    int limit,
  })?
  _nearbyQuery;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<TripModel> get driverTrips => _driverTrips;
  List<TripModel> get activeTrips => _activeTrips;

  TripProvider() {
    _socket.connect();
    _initSocketListeners();
  }

  @override
  void dispose() {
    _driverTripsController.close();
    _activeTripsController.close();
    _nearbyTripsController.close();
    super.dispose();
  }

  void _initSocketListeners() {
    // Listen for trip updates from WebSocket
    _socket.onTripUpdated.listen((data) {
      // Find and update the trip in activeTrips
      final tripId = data['tripId'] ?? data['_id'];
      if (tripId == null) return;

      int index = _activeTrips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        // Here you would optimally parse the updated trip from data
        // For now, we'll just re-fetch the trips to ensure consistency
        _refetchActiveTrips();
      }
      if (_nearbyTrips.any((t) => t.id == tripId)) {
        fetchNearbyTrips();
      }

      int driverIndex = _driverTrips.indexWhere((t) => t.id == tripId);
      if (driverIndex != -1) {
        fetchDriverTrips();
      }
    });

    _socket.onSeatUpdated.listen((data) {
      final tripId = data['tripId'];
      if (tripId != null) {
        // Re-fetch trips if one of our loaded trips was updated
        if (_activeTrips.any((t) => t.id == tripId) ||
            _driverTrips.any((t) => t.id == tripId)) {
          _refetchActiveTrips();
          fetchDriverTrips();
        }
        if (_nearbyTrips.any((t) => t.id == tripId)) {
          fetchNearbyTrips();
        }
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  // Create a new trip — seat layout is read from the driver's vehicle
  // server-side, so callers don't pass it here.
  Future<String?> createTrip({
    required LocationModel from,
    required LocationModel to,
    required DateTime departureTime,
    required double price,
    required String currency,
    File? carImage,
    List<LocationModel>? stops,
    String? notes,
    TripMeetingPoint? meetingPoint,
    Map<String, dynamic>? recurrence,
    int? availableSeats,
    List<String>? closedSeatNumbers,
    bool? preventGenderMixing,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final tripId = await _tripService.createTrip(
        from: from,
        to: to,
        departureTime: departureTime,
        price: price,
        currency: currency,
        carImageUrl: null,
        stops: stops,
        notes: notes,
        meetingPoint: meetingPoint,
        recurrence: recurrence,
        availableSeats: availableSeats,
        closedSeatNumbers: closedSeatNumbers,
        preventGenderMixing: preventGenderMixing,
      );

      await fetchDriverTrips();

      _setLoading(false);
      return tripId;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      // Propagate the original error (typically a mapped Failure) so callers
      // can react to specific backend codes — e.g. the create-trip screen's
      // insufficient-balance-for-trip-fee dialog. Previously this swallowed
      // every failure into a null return, losing that information.
      rethrow;
    }
  }

  // Get trip by ID
  Future<TripModel?> getTrip(String tripId) async {
    return await _tripService.getTrip(tripId);
  }

  /// Driver: lock/unlock seat (external booking).
  Future<bool> setSeatLock(
    String tripId, {
    required String seatNumber,
    required bool locked,
  }) async {
    try {
      await _tripService.setSeatLock(
        tripId,
        seatNumber: seatNumber,
        locked: locked,
      );
      await fetchDriverTrips();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> fetchDriverTrips({
    String? status,
    String? driverId,
    String? driverName,
  }) async {
    try {
      _setLoading(true);
      _driverTrips = await _tripService.getDriverTrips(
        status: status,
        driverId: driverId,
        driverName: driverName,
      );
      _driverTripsController.add(_driverTrips);
      _setError(null);
    } catch (e) {
      _driverTripsController.add(_driverTrips);
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Stream<List<TripModel>> getDriverTripsStream(
    String driverId, {
    String? status,
    String? driverName,
  }) async* {
    final key = status ?? 'all';
    if (!_loadedDriverTripsKeys.contains(key)) {
      _loadedDriverTripsKeys.add(key);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          fetchDriverTrips(
            status: status,
            driverId: driverId,
            driverName: driverName,
          ),
        );
      });
    }
    yield _driverTrips;
    yield* _driverTripsController.stream;
  }

  Stream<List<TripModel>> getActiveTripsStream({
    LocationModel? from,
    LocationModel? to,
    DateTime? minDepartureTime,
    String? country,
  }) async* {
    final key =
        '${_buildActiveTripsKey(from: from, to: to, minDepartureTime: minDepartureTime)}|${country ?? ''}';
    if (!_loadedActiveTripsKeys.contains(key)) {
      _loadedActiveTripsKeys.add(key);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          fetchActiveTrips(
            from: from,
            to: to,
            minDepartureTime: minDepartureTime,
            country: country,
          ),
        );
      });
    }
    yield _activeTrips;
    yield* _activeTripsController.stream;
  }

  String _buildActiveTripsKey({
    LocationModel? from,
    LocationModel? to,
    DateTime? minDepartureTime,
  }) {
    final fromKey = from == null
        ? 'null'
        : '${from.latitude},${from.longitude}';
    final toKey = to == null ? 'null' : '${to.latitude},${to.longitude}';
    final normalizedTime = minDepartureTime == null
        ? 'null'
        : DateTime(
            minDepartureTime.year,
            minDepartureTime.month,
            minDepartureTime.day,
            minDepartureTime.hour,
            minDepartureTime.minute,
          ).toIso8601String();
    return '$fromKey|$toKey|$normalizedTime';
  }

  Future<Failure?> deleteTrip(String tripId) => cancelTrip(tripId);

  Future<bool> updateTrip(String tripId, Map<String, dynamic> updates) async {
    // NOTE: Fallback stub for legacy api. Update your endpoint logic.
    await fetchDriverTrips();
    return true;
  }

  // Fetch active trips and update state
  Future<void> fetchActiveTrips({
    LocationModel? from,
    LocationModel? to,
    DateTime? minDepartureTime,
    String? country,
  }) async {
    _lastActiveQuery = (
      from: from,
      to: to,
      minDepartureTime: minDepartureTime,
      country: country,
    );
    try {
      _setLoading(true);
      _activeTrips = await _tripService.searchActiveTrips(
        from: from,
        to: to,
        minDepartureTime: minDepartureTime,
        country: country,
      );
      _activeTripsController.add(_activeTrips);
      _setError(null);
    } catch (e) {
      _activeTripsController.add(_activeTrips);
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  ({
    LocationModel? from,
    LocationModel? to,
    DateTime? minDepartureTime,
    String? country,
  })?
  _lastActiveQuery;

  /// Socket-driven refresh: same filters as the list currently on screen.
  Future<void> _refetchActiveTrips() {
    final q = _lastActiveQuery;
    return fetchActiveTrips(
      from: q?.from,
      to: q?.to,
      minDepartureTime: q?.minDepartureTime,
      country: q?.country,
    );
  }

  // Hide trip
  Future<bool> hideTrip(String tripId) async {
    try {
      _setLoading(true);
      await _tripService.hideTrip(tripId);
      await fetchDriverTrips();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Show trip
  Future<bool> showTrip(String tripId) async {
    try {
      _setLoading(true);
      await _tripService.showTrip(tripId);
      await fetchDriverTrips();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Cancel/Delete trip
  /// Null on success, or why the backend refused (e.g. within 24 hours of
  /// departure) so the screen can say so.
  Future<Failure?> cancelTrip(String tripId) async {
    try {
      _setLoading(true);
      await _tripService.cancelTrip(tripId);
      await fetchDriverTrips();
      _setLoading(false);
      return null;
    } catch (e) {
      final failure = ApiClient.mapError(e);
      _setError(failure.developerDetail);
      _setLoading(false);
      return failure;
    }
  }

  /// Trips leaving near [userLocation], nearest first. The radius is applied
  /// by the backend over every upcoming trip — filtering a first page of the
  /// global list here used to drop nearby trips that departed later than 20
  /// trips elsewhere.
  Stream<List<TripModel>> getNearbyTripsStream({
    required String excludeDriverId,
    required LocationModel userLocation,
    double maxDistanceKm = 100,
    int limit = 5,
  }) async* {
    final key =
        '${userLocation.latitude},${userLocation.longitude}|$excludeDriverId|$maxDistanceKm|$limit';
    if (_nearbyKey != key) {
      _nearbyKey = key;
      _nearbyQuery = (
        location: userLocation,
        excludeDriverId: excludeDriverId,
        radiusKm: maxDistanceKm,
        limit: limit,
      );
      _nearbyTrips = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(fetchNearbyTrips());
      });
    }
    yield _nearbyTrips;
    yield* _nearbyTripsController.stream;
  }

  /// Re-runs the last nearby query (pull-to-refresh, seat updates).
  Future<void> fetchNearbyTrips() async {
    final query = _nearbyQuery;
    if (query == null) return;
    final trips = await _tripService.getNearbyTrips(
      riderLocation: query.location,
      radiusKm: query.radiusKm,
    );
    // A newer location may have been set while this was in flight.
    if (!identical(query, _nearbyQuery)) return;
    _nearbyTrips = trips
        .where((trip) => trip.driverId != query.excludeDriverId)
        .take(query.limit)
        .toList();
    if (!_nearbyTripsController.isClosed) {
      _nearbyTripsController.add(_nearbyTrips);
    }
  }

  // Subscribe to trip for real-time seat updates
  void subscribeToTrip(String tripId) {
    _socket.subscribeToTrip(tripId);
  }

  void unsubscribeFromTrip(String tripId) {
    _socket.unsubscribeFromTrip(tripId);
  }
}
