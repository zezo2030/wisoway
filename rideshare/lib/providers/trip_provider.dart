import 'package:flutter/widgets.dart';
import 'dart:io';
import '../core/services/trip_service.dart';
import '../core/api/websocket_service.dart';
import '../models/trip_model.dart';
import 'dart:async';
import '../models/location_model.dart';
import '../models/seat_layout_config.dart';

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
        fetchActiveTrips();
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
          fetchActiveTrips();
          fetchDriverTrips();
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

  // Create a new trip
  Future<String?> createTrip({
    required LocationModel from,
    required LocationModel to,
    required DateTime departureTime,
    required double price,
    required String currency,
    required SeatLayoutConfig seatLayout,
    File? carImage,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Note: Image upload should ideally be handled here via a generic upload service
      // But for the scope of the provider update, we pass null or skip image logic
      // since we removed storage_service which was hardcoded to Firebase.

      final tripId = await _tripService.createTrip(
        from: from,
        to: to,
        departureTime: departureTime,
        price: price,
        currency: currency,
        seatLayout: seatLayout,
        carImageUrl: null,
      );

      await fetchDriverTrips();

      _setLoading(false);
      return tripId;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
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
  }) async* {
    final key = _buildActiveTripsKey(
      from: from,
      to: to,
      minDepartureTime: minDepartureTime,
    );
    if (!_loadedActiveTripsKeys.contains(key)) {
      _loadedActiveTripsKeys.add(key);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          fetchActiveTrips(
            from: from,
            to: to,
            minDepartureTime: minDepartureTime,
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
    final fromKey = from == null ? 'null' : '${from.latitude},${from.longitude}';
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

  Future<bool> deleteTrip(String tripId) async {
    return cancelTrip(tripId);
  }

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
  }) async {
    try {
      _setLoading(true);
      _activeTrips = await _tripService.searchActiveTrips(
        from: from,
        to: to,
        minDepartureTime: minDepartureTime,
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
  Future<bool> cancelTrip(String tripId) async {
    try {
      _setLoading(true);
      await _tripService.cancelTrip(tripId);
      await fetchDriverTrips();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
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
