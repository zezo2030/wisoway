import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/location_model.dart';

/// What a stored place is used for in the search screen's default list.
enum SavedPlaceKind {
  /// A place the user confirmed on a trip. Capped and evicted oldest-first.
  recent,

  /// The fixed "Home" shortcut.
  home,

  /// The fixed "Work" shortcut.
  work,

  /// A user-named shortcut.
  custom,
}

/// A place remembered between sessions, shown before the user types.
class SavedPlace {
  final SavedPlaceKind kind;

  /// User-chosen name for a shortcut; empty for a recent place, which is
  /// labelled by the provider's own [name].
  final String label;
  final String name;
  final String secondaryText;
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  const SavedPlace({
    required this.kind,
    required this.label,
    required this.name,
    required this.secondaryText,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  LocationModel toLocation() => LocationModel(
    name: name,
    latitude: latitude,
    longitude: longitude,
    address: secondaryText.isEmpty ? name : '$name، $secondaryText',
  );

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'label': label,
    'name': name,
    'secondaryText': secondaryText,
    'lat': latitude,
    'lng': longitude,
    'savedAt': savedAt.millisecondsSinceEpoch,
  };

  static SavedPlace? fromMap(Map<String, dynamic> map) {
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final name = map['name']?.toString() ?? '';
    // A stored entry without a usable point can never be selected, so drop it
    // rather than surface a row that fails when tapped.
    if (lat == null || lng == null || name.isEmpty) return null;

    return SavedPlace(
      kind: SavedPlaceKind.values.firstWhere(
        (value) => value.name == map['kind'],
        orElse: () => SavedPlaceKind.recent,
      ),
      label: map['label']?.toString() ?? '',
      name: name,
      secondaryText: map['secondaryText']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['savedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// Local store for the search screen's shortcuts and recent places.
///
/// Entries are scoped to a user id so two accounts on one device never see
/// each other's places, and only confirmed selections are written — a partial
/// search string is never stored. Purely on-device; there is no sync yet.
class SavedPlacesService {
  static const String _prefix = 'saved_places';
  static const int maxRecents = 10;

  /// Two places within this many metres are treated as the same spot, so
  /// re-picking a place moves it to the top instead of adding a duplicate row.
  static const double _samePlaceMeters = 60;

  final String userId;

  SavedPlacesService({required this.userId});

  String get _key => '$_prefix:$userId';

  Future<List<SavedPlace>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => SavedPlace.fromMap(Map<String, dynamic>.from(item)))
          .whereType<SavedPlace>()
          .toList();
    } catch (_) {
      // Corrupted storage must not block searching; start fresh instead.
      return const [];
    }
  }

  Future<void> _writeAll(List<SavedPlace> places) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(places.map((place) => place.toMap()).toList()),
    );
  }

  /// Shortcuts, in the order the search screen lists them: Home, Work, then
  /// any custom ones, newest first.
  Future<List<SavedPlace>> shortcuts() async {
    final all = await _readAll();
    final home = all.where((p) => p.kind == SavedPlaceKind.home).toList();
    final work = all.where((p) => p.kind == SavedPlaceKind.work).toList();
    final custom = all.where((p) => p.kind == SavedPlaceKind.custom).toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return [...home, ...work, ...custom];
  }

  /// Recently confirmed places, newest first, excluding anything already
  /// shown as a shortcut so the list has no duplicate rows.
  Future<List<SavedPlace>> recents() async {
    final all = await _readAll();
    final shortcutPlaces = all
        .where((place) => place.kind != SavedPlaceKind.recent)
        .toList();

    return all
        .where((place) => place.kind == SavedPlaceKind.recent)
        .where(
          (place) => !shortcutPlaces.any(
            (shortcut) => _isSameSpot(place, shortcut),
          ),
        )
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  /// Record a place the user actually confirmed for a trip endpoint.
  ///
  /// Call this only on a confirmed selection (a chosen suggestion or a
  /// confirmed map point), never while the user is still typing.
  Future<void> addRecent(LocationModel location, {String secondaryText = ''}) async {
    final entry = SavedPlace(
      kind: SavedPlaceKind.recent,
      label: '',
      name: location.name,
      secondaryText: secondaryText,
      latitude: location.latitude,
      longitude: location.longitude,
      savedAt: DateTime.now(),
    );

    final all = await _readAll();
    final recents = all
        .where((place) => place.kind == SavedPlaceKind.recent)
        .where((place) => !_isSameSpot(place, entry))
        .toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    final trimmed = [entry, ...recents].take(maxRecents).toList();
    final others = all
        .where((place) => place.kind != SavedPlaceKind.recent)
        .toList();
    await _writeAll([...others, ...trimmed]);
  }

  /// Create or replace a shortcut. Home and Work are singletons; a custom
  /// shortcut replaces any existing one with the same [label].
  Future<void> saveShortcut({
    required SavedPlaceKind kind,
    required String label,
    required LocationModel location,
    String secondaryText = '',
  }) async {
    if (kind == SavedPlaceKind.recent) return;

    final all = await _readAll();
    final kept = all.where((place) {
      if (place.kind == SavedPlaceKind.recent) return true;
      if (kind == SavedPlaceKind.custom) {
        return !(place.kind == SavedPlaceKind.custom && place.label == label);
      }
      return place.kind != kind;
    }).toList();

    kept.add(
      SavedPlace(
        kind: kind,
        label: label,
        name: location.name,
        secondaryText: secondaryText,
        latitude: location.latitude,
        longitude: location.longitude,
        savedAt: DateTime.now(),
      ),
    );
    await _writeAll(kept);
  }

  Future<void> removeShortcut(SavedPlaceKind kind, {String label = ''}) async {
    if (kind == SavedPlaceKind.recent) return;
    final all = await _readAll();
    await _writeAll(
      all
          .where(
            (place) =>
                place.kind != kind ||
                (kind == SavedPlaceKind.custom && place.label != label),
          )
          .toList(),
    );
  }

  Future<void> clearRecents() async {
    final all = await _readAll();
    await _writeAll(
      all.where((place) => place.kind != SavedPlaceKind.recent).toList(),
    );
  }

  /// Drop everything for this user. Call on sign-out so places do not leak to
  /// the next account on the device.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  bool _isSameSpot(SavedPlace a, SavedPlace b) {
    // Rough metres-per-degree, good enough to collapse near-identical pins.
    const metersPerDegree = 111_320.0;
    final dLat = (a.latitude - b.latitude).abs() * metersPerDegree;
    final dLng = (a.longitude - b.longitude).abs() * metersPerDegree;
    return dLat < _samePlaceMeters && dLng < _samePlaceMeters;
  }
}
