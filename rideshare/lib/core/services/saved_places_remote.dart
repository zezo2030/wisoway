import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import 'saved_places_service.dart';

/// Account-side store for Home, Work and named places, so they follow the
/// user across devices. Recents never leave the device.
abstract class SavedPlacesRemote {
  Future<List<SavedPlace>> list();

  /// Creates or moves the place; returns it as stored, with its id.
  Future<SavedPlace> upsert(SavedPlace place);

  Future<void> delete(String id);
}

/// [SavedPlacesRemote] over `/me/saved-places`.
class ApiSavedPlacesRemote implements SavedPlacesRemote {
  final ApiClient _api;

  ApiSavedPlacesRemote({ApiClient? api}) : _api = api ?? ApiClient();

  static dynamic _unwrap(dynamic response) =>
      response is Map && response.containsKey('data')
      ? response['data']
      : response;

  @override
  Future<List<SavedPlace>> list() async {
    final data = _unwrap(await _api.get(ApiEndpoints.mySavedPlaces));
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => SavedPlace.fromApi(Map<String, dynamic>.from(item)))
        .whereType<SavedPlace>()
        .toList();
  }

  @override
  Future<SavedPlace> upsert(SavedPlace place) async {
    final data = _unwrap(
      await _api.put(
        ApiEndpoints.mySavedPlaces,
        data: {
          'kind': place.kind.name,
          if (place.kind == SavedPlaceKind.custom) 'label': place.label,
          'name': place.name,
          'secondaryText': place.secondaryText,
          'latitude': place.latitude,
          'longitude': place.longitude,
        },
      ),
    );
    final saved = data is Map
        ? SavedPlace.fromApi(Map<String, dynamic>.from(data))
        : null;
    return saved ?? place;
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete('${ApiEndpoints.mySavedPlaces}/$id');
  }
}
