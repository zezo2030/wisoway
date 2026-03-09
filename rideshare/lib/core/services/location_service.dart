import 'dart:ui';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/location_model.dart';

class LocationService {
  static final RegExp _plusCodeRegex = RegExp(
    r'^[23456789CFGHJMPQRVWX]{2,}\+[23456789CFGHJMPQRVWX]{2,}$',
    caseSensitive: false,
  );

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Check location permissions
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  // Request location permissions
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  // Get current location
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Get address from coordinates (Geocoding)
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final cleanedCountry = _sanitizeAddressPart(place.country);
        // Build a readable address and ignore noisy plus-code fragments.
        final candidateParts = <String?>[
          if (!_hasText(place.subLocality) && !_hasText(place.locality))
            place.street,
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ];

        final seen = <String>{};
        final addressParts = <String>[];
        for (final rawPart in candidateParts) {
          final cleanedPart = _sanitizeAddressPart(rawPart);
          if (cleanedPart == null) continue;

          final dedupeKey = cleanedPart.toLowerCase();
          if (seen.add(dedupeKey)) {
            addressParts.add(cleanedPart);
          }
        }

        if (cleanedCountry != null && addressParts.length > 2) {
          addressParts.removeWhere(
            (part) => part.toLowerCase() == cleanedCountry.toLowerCase(),
          );
        }

        if (addressParts.length > 3) {
          addressParts.removeRange(3, addressParts.length);
        }

        return addressParts.isNotEmpty
            ? addressParts.join('، ')
            : _unknownLocationLabel;
      }

      return _unknownLocationLabel;
    } catch (e) {
      print('❌ Error getting address from coordinates: $e');
      return _unknownLocationLabel;
    }
  }

  // Get coordinates from address (Geocoding)
  Future<LocationModel?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final addressString = await getAddressFromCoordinates(
          latitude: location.latitude,
          longitude: location.longitude,
        );

        return LocationModel(
          name: address,
          latitude: location.latitude,
          longitude: location.longitude,
          address: addressString,
        );
      }

      return null;
    } catch (e) {
      print('❌ Error getting coordinates from address: $e');
      return null;
    }
  }

  // Create LocationModel from current position
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

  // Calculate distance between two locations in kilometers
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  // Calculate distance between two LocationModel objects
  double calculateDistanceBetweenLocations(LocationModel loc1, LocationModel loc2) {
    return calculateDistance(
      lat1: loc1.latitude,
      lon1: loc1.longitude,
      lat2: loc2.latitude,
      lon2: loc2.longitude,
    );
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

  bool _looksLikePlusCode(String value) {
    final compact = value.replaceAll(' ', '').toUpperCase();
    return _plusCodeRegex.hasMatch(compact);
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  bool get _isArabicLocale {
    final languageCode =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return languageCode.startsWith('ar');
  }

  String get _unknownLocationLabel {
    return _isArabicLocale ? 'موقع غير معروف' : 'Unknown location';
  }
}

