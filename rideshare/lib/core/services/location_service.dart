import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/location_model.dart';

class LocationService {
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
        // Build address string
        final addressParts = <String>[];
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        return addressParts.isNotEmpty ? addressParts.join(', ') : 'Unknown location';
      }

      return 'Unknown location';
    } catch (e) {
      print('❌ Error getting address from coordinates: $e');
      return 'Unknown location';
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
}

