import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/location_model.dart';
import 'saved_places_remote.dart';

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
  /// Account-side id; null for a recent place and for a shortcut that has not
  /// reached the account yet.
  final String? id;
  final SavedPlaceKind kind;

  /// User-chosen name of a custom shortcut. Empty for Home and Work, which
  /// the UI names in the current language, and for a recent place, which is
  /// labelled by the provider's own [name].
  final String label;
  final String name;
  final String secondaryText;
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  const SavedPlace({
    this.id,
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
    if (id != null) 'id': id,
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
      id: map['id']?.toString(),
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

  /// A row of `GET /me/saved-places`; null when it is not a usable shortcut.
  static SavedPlace? fromApi(Map<String, dynamic> map) {
    final kind = SavedPlaceKind.values
        .where((value) => value.name == map['kind'])
        .firstOrNull;
    if (kind == null || kind == SavedPlaceKind.recent) return null;
    final updatedAt = DateTime.tryParse(map['updatedAt']?.toString() ?? '');
    return fromMap({
      'id': map['id'],
      'kind': kind.name,
      'label': map['label'],
      'name': map['name'],
      'secondaryText': map['secondaryText'],
      'lat': map['latitude'],
      'lng': map['longitude'],
      'savedAt': (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }
}

/// Store for the search screen's shortcuts and recent places.
///
/// Entries are scoped to a user id so two accounts on one device never see
/// each other's places, and only confirmed selections are written — a partial
/// search string is never stored.
///
/// With a [remote] (a signed-in user), shortcuts live on the account and the
/// local copy is a cache that keeps them available offline; shortcuts saved
/// on this device before syncing existed are uploaded once. Recents always
/// stay on the device.
class SavedPlacesService {
  static const String _prefix = 'saved_places';
  static const String _migratedPrefix = 'saved_places_migrated';
  static const int maxRecents = 10;

  /// How long the search screen waits for the account before it falls back
  /// to the cached shortcuts.
  static const Duration remoteTimeout = Duration(seconds: 4);

  /// Two places within this many metres are treated as the same spot, so
  /// re-picking a place moves it to the top instead of adding a duplicate row.
  static const double _samePlaceMeters = 60;

  final String userId;
  final SavedPlacesRemote? remote;

  SavedPlacesService({required this.userId, this.remote});

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

  /// Replace the cached shortcuts, keeping the device's recents.
  Future<void> _cacheShortcuts(List<SavedPlace> shortcuts) async {
    final recents = (await _readAll())
        .where((place) => place.kind == SavedPlaceKind.recent)
        .toList();
    await _writeAll([...shortcuts, ...recents]);
  }

  /// Pull the account's shortcuts into the cache, first uploading any this
  /// device saved before it synced. Throws when the account is unreachable.
  Future<void> _syncFromRemote(SavedPlacesRemote remote) async {
    var serverPlaces = await remote.list().timeout(remoteTimeout);

    final prefs = await SharedPreferences.getInstance();
    final migratedKey = '$_migratedPrefix:$userId';
    if (prefs.getBool(migratedKey) != true) {
      final localOnly = (await _readAll()).where(
        (place) =>
            place.kind != SavedPlaceKind.recent &&
            place.id == null &&
            // The account's copy wins over a stale device copy.
            !serverPlaces.any((s) => _sameShortcut(s, place)),
      );
      for (final place in localOnly) {
        await remote.upsert(place);
      }
      await prefs.setBool(migratedKey, true);
      if (localOnly.isNotEmpty) serverPlaces = await remote.list();
    }

    await _cacheShortcuts(serverPlaces);
  }

  /// Shortcuts, in the order the search screen lists them: Home, Work, then
  /// any custom ones, newest first.
  Future<List<SavedPlace>> shortcuts() async {
    final remote = this.remote;
    if (remote != null) {
      try {
        await _syncFromRemote(remote);
      } catch (_) {
        // Offline or the account is unreachable: the cache is still correct
        // as of the last sync, and shortcuts are only a convenience.
      }
    }

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
  Future<void> addRecent(
    LocationModel location, {
    String secondaryText = '',
  }) async {
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
  /// shortcut replaces any existing one with the same [label]. With a
  /// [remote] this throws when the account could not be updated, and nothing
  /// changes locally.
  Future<void> saveShortcut({
    required SavedPlaceKind kind,
    required String label,
    required LocationModel location,
    String secondaryText = '',
  }) async {
    if (kind == SavedPlaceKind.recent) return;

    var place = SavedPlace(
      kind: kind,
      label: kind == SavedPlaceKind.custom ? label.trim() : '',
      name: location.name,
      secondaryText: secondaryText,
      latitude: location.latitude,
      longitude: location.longitude,
      savedAt: DateTime.now(),
    );
    final remote = this.remote;
    if (remote != null) place = await remote.upsert(place);

    final all = await _readAll();
    final kept = all
        .where(
          (existing) =>
              existing.kind == SavedPlaceKind.recent ||
              !_sameShortcut(existing, place),
        )
        .toList();
    await _writeAll([...kept, place]);
  }

  /// With a [remote] this throws when the account could not be updated, and
  /// nothing changes locally.
  Future<void> removeShortcut(SavedPlaceKind kind, {String label = ''}) async {
    if (kind == SavedPlaceKind.recent) return;
    final probe = SavedPlace(
      kind: kind,
      label: kind == SavedPlaceKind.custom ? label : '',
      name: '',
      secondaryText: '',
      latitude: 0,
      longitude: 0,
      savedAt: DateTime.now(),
    );
    final all = await _readAll();

    final remote = this.remote;
    if (remote != null) {
      for (final place in all.where((p) => _sameShortcut(p, probe))) {
        final id = place.id;
        if (id != null) await remote.delete(id);
      }
    }

    await _writeAll(all.where((p) => !_sameShortcut(p, probe)).toList());
  }

  Future<void> clearRecents() async {
    final all = await _readAll();
    await _writeAll(
      all.where((place) => place.kind != SavedPlaceKind.recent).toList(),
    );
  }

  /// Drop this device's copy for this user. Call on sign-out so places do not
  /// leak to the next account on the device; the account keeps its shortcuts.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Same Home, same Work, or a custom shortcut with the same label.
  bool _sameShortcut(SavedPlace a, SavedPlace b) {
    if (a.kind != b.kind || a.kind == SavedPlaceKind.recent) return false;
    return a.kind != SavedPlaceKind.custom || a.label == b.label;
  }

  bool _isSameSpot(SavedPlace a, SavedPlace b) {
    // Rough metres-per-degree, good enough to collapse near-identical pins.
    const metersPerDegree = 111_320.0;
    final dLat = (a.latitude - b.latitude).abs() * metersPerDegree;
    final dLng = (a.longitude - b.longitude).abs() * metersPerDegree;
    return dLat < _samePlaceMeters && dLng < _samePlaceMeters;
  }
}
