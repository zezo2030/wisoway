import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../../models/location_model.dart';

class PlaceSuggestion {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String description;

  /// Straight-line metres from the search context the request carried, or null
  /// when none was sent. Drives the trailing distance label on a result row.
  final int? distanceMeters;

  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.description,
    this.distanceMeters,
  });

  factory PlaceSuggestion.fromMap(Map<String, dynamic> map) {
    final distance = map['distanceMeters'];
    return PlaceSuggestion(
      placeId: map['placeId']?.toString() ?? '',
      primaryText: map['primaryText']?.toString() ?? '',
      secondaryText: map['secondaryText']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      distanceMeters: distance is num ? distance.round() : null,
    );
  }
}

class LocationAutocompleteResult {
  final String sessionToken;
  final List<PlaceSuggestion> suggestions;

  const LocationAutocompleteResult({
    required this.sessionToken,
    required this.suggestions,
  });
}

/// A resolved map point: the two address lines shown above the picker's pin.
class ReverseGeocodeResult {
  final String primaryText;
  final String secondaryText;
  final String label;
  final double latitude;
  final double longitude;

  const ReverseGeocodeResult({
    required this.primaryText,
    required this.secondaryText,
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  /// True when the provider knew no address for the point. The point is still
  /// confirmable; the app just shows "address unavailable" instead of a name.
  bool get isEmpty => label.trim().isEmpty;

  factory ReverseGeocodeResult.fromMap(Map<String, dynamic> map) {
    return ReverseGeocodeResult(
      primaryText: map['primaryText']?.toString() ?? '',
      secondaryText: map['secondaryText']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      latitude: (map['lat'] as num?)?.toDouble() ?? 0,
      longitude: (map['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LocationService {
  static const String _keyLocationSharing = 'privacy_location_sharing';
  static const String _arabicLocaleIdentifier = 'ar';
  final ApiClient _apiClient;

  LocationService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  static final RegExp _plusCodeRegex = RegExp(
    r'^[23456789CFGHJMPQRVWX]{2,}\+[23456789CFGHJMPQRVWX]{2,}$',
    caseSensitive: false,
  );

  Future<bool> isLocationSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLocationSharing) ?? true;
  }

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  Future<Position> getCurrentPosition({
    bool checkPrivacyPreference = true,
  }) async {
    if (checkPrivacyPreference) {
      final sharingEnabled = await isLocationSharingEnabled();
      if (!sharingEnabled) {
        throw Exception('LOCATION_SHARING_DISABLED');
      }
    }

    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('LOCATION_SERVICE_DISABLED');
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('LOCATION_PERMISSION_DENIED');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('LOCATION_PERMISSION_PERMANENTLY_DENIED');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await _getLocalizedPlacemarks(
        latitude: latitude,
        longitude: longitude,
      );

      if (placemarks.isEmpty) {
        return _unknownLocationLabel;
      }

      return _buildShortAddress(placemarks.first);
    } on PlatformException catch (e) {
      if (e.code == 'IO_ERROR' ||
          (e.message?.contains('Service not Available') ?? false)) {
        print(
          'Warning: geocoding unavailable (Google Play Services or network).',
        );
      } else {
        print('Error getting address from coordinates: $e');
      }
      return _unknownLocationLabel;
    } catch (e) {
      print('Error getting address from coordinates: $e');
      return _unknownLocationLabel;
    }
  }

  // Text → coordinates deliberately has no on-device path. All place search
  // goes through `autocomplete` + `placeDetail`, so a name can only ever
  // resolve one way and the list and the resolved point cannot disagree.

  Future<LocationModel> getCurrentLocation() async {
    final position = await getCurrentPosition();
    final address = await getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return LocationModel(
      name: address,
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
    );
  }

  Future<LocationAutocompleteResult> autocomplete({
    required String query,
    String? lang,
    String? sessionToken,
    double? latitude,
    double? longitude,
    CancelToken? cancelToken,
  }) async {
    // The backend ignores a lone coordinate, so only send a complete pair.
    final hasContext = latitude != null && longitude != null;
    final response = await _apiClient.get(
      ApiEndpoints.locationsAutocomplete,
      cancelToken: cancelToken,
      queryParameters: {
        'q': query,
        'lang': lang ?? _languageCode,
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        if (hasContext) 'lat': latitude,
        if (hasContext) 'lng': longitude,
      },
    );

    final data = _unwrapResponse(response);
    final suggestions = (data['suggestions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => PlaceSuggestion.fromMap(Map<String, dynamic>.from(item)))
        .where((suggestion) => suggestion.placeId.isNotEmpty)
        .toList();

    return LocationAutocompleteResult(
      sessionToken: data['sessionToken']?.toString() ?? sessionToken ?? '',
      suggestions: suggestions,
    );
  }

  Future<LocationModel> placeDetail({
    required String placeId,
    String? sessionToken,
    CancelToken? cancelToken,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.locationsPlace(placeId),
      cancelToken: cancelToken,
      queryParameters: {
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
      },
    );

    final data = _unwrapResponse(response);
    final label = data['label']?.toString() ?? '';
    return LocationModel(
      name: label,
      latitude: (data['lat'] as num).toDouble(),
      longitude: (data['lng'] as num).toDouble(),
      address: label,
    );
  }

  /// Resolve a map point to a display address through the backend, so the map
  /// picker labels a point the same way the search list would name it.
  ///
  /// Falls back to the on-device geocoder only when the backend is
  /// unreachable, so moving the pin still shows something offline.
  Future<ReverseGeocodeResult> reverseGeocode({
    required double latitude,
    required double longitude,
    String? lang,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.locationsReverse,
        cancelToken: cancelToken,
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
          'lang': lang ?? _languageCode,
        },
      );

      final data = _unwrapResponse(response);
      final result = ReverseGeocodeResult.fromMap(data);
      // Keep the caller's exact point: the backend echoes it, but a rounded
      // echo must never move the pin the user placed.
      return ReverseGeocodeResult(
        primaryText: result.primaryText,
        secondaryText: result.secondaryText,
        label: result.label,
        latitude: latitude,
        longitude: longitude,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      return _deviceReverseGeocode(latitude, longitude);
    } catch (_) {
      return _deviceReverseGeocode(latitude, longitude);
    }
  }

  Future<ReverseGeocodeResult> _deviceReverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final address = await getAddressFromCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
    final resolved = address == _unknownLocationLabel ? '' : address;
    return ReverseGeocodeResult(
      primaryText: resolved,
      secondaryText: '',
      label: resolved,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// True when the app is rendering Arabic, used to pick city display names.
  bool get isArabic => _isArabicLocale;

  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  double calculateDistanceBetweenLocations(
    LocationModel loc1,
    LocationModel loc2,
  ) {
    return calculateDistance(
      lat1: loc1.latitude,
      lon1: loc1.longitude,
      lat2: loc2.latitude,
      lon2: loc2.longitude,
    );
  }

  Future<List<Placemark>> _getLocalizedPlacemarks({
    required double latitude,
    required double longitude,
  }) async {
    await _useArabicLocale();
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isNotEmpty && _placemarkLooksArabic(placemarks.first)) {
      return placemarks;
    }

    return placemarks;
  }

  Future<void> _useArabicLocale() {
    return setLocaleIdentifier(_arabicLocaleIdentifier);
  }

  String _buildShortAddress(Placemark place) {
    final primaryParts = _uniqueAddressParts([
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ]);

    if (primaryParts.length >= 2) {
      return primaryParts.take(2).join('، ');
    }

    final fallbackParts = _uniqueAddressParts([
      if (!_hasText(place.subLocality) && !_hasText(place.locality))
        place.street,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.country,
    ]);

    if (fallbackParts.isEmpty) {
      return _unknownLocationLabel;
    }

    return fallbackParts.take(2).join('، ');
  }

  List<String> _uniqueAddressParts(List<String?> values) {
    final seen = <String>{};
    final parts = <String>[];

    for (final value in values) {
      final cleaned = _sanitizeAddressPart(value);
      if (cleaned == null) {
        continue;
      }

      final normalized = cleaned.toLowerCase();
      if (seen.add(normalized)) {
        parts.add(cleaned);
      }
    }

    return parts;
  }

  String? _sanitizeAddressPart(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final segments = value
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .where((segment) => !_looksLikePlusCode(segment));

    final cleaned = segments.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  bool _placemarkLooksArabic(Placemark place) {
    final combined = [
      place.street,
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
      place.country,
    ].whereType<String>().join(' ');

    return RegExp(r'[\u0600-\u06FF]').hasMatch(combined);
  }

  bool _looksLikePlusCode(String value) {
    final compact = value.replaceAll(' ', '').toUpperCase();
    return _plusCodeRegex.hasMatch(compact);
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String? get _preferredLocaleIdentifier {
    final locale = PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.trim();
    if (languageCode.isEmpty) {
      return null;
    }

    final countryCode = locale.countryCode?.trim();
    if (countryCode == null || countryCode.isEmpty) {
      return languageCode;
    }

    return '${languageCode}_$countryCode';
  }

  bool get _isArabicLocale {
    final languageCode = PlatformDispatcher.instance.locale.languageCode
        .toLowerCase();
    return languageCode.startsWith('ar');
  }

  String get _languageCode => _isArabicLocale ? 'ar' : 'en';

  Map<String, dynamic> _unwrapResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      return response;
    }
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final data = map['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return map;
    }
    return <String, dynamic>{};
  }

  String get _unknownLocationLabel {
    return 'موقع غير معروف';
  }
}
