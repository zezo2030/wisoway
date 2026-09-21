import 'dart:ui';

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

  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.description,
  });

  factory PlaceSuggestion.fromMap(Map<String, dynamic> map) {
    return PlaceSuggestion(
      placeId: map['placeId']?.toString() ?? '',
      primaryText: map['primaryText']?.toString() ?? '',
      secondaryText: map['secondaryText']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
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

  Future<LocationModel?> getCoordinatesFromAddress(String address) async {
    try {
      await _useArabicLocale();
      final locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return null;
      }

      final location = locations.first;
      final addressString = await getAddressFromCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      return LocationModel(
        name: addressString,
        latitude: location.latitude,
        longitude: location.longitude,
        address: addressString,
      );
    } catch (e) {
      print('Error getting coordinates from address: $e');
      return null;
    }
  }

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
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.locationsAutocomplete,
      queryParameters: {
        'q': query,
        'lang': lang ?? _languageCode,
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
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
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.locationsPlace(placeId),
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
