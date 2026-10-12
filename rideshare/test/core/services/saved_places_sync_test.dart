import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/saved_places_remote.dart';
import 'package:rideshare/core/services/saved_places_service.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

LocationModel _place(String name, {double lat = 31.9, double lng = 35.9}) =>
    LocationModel(name: name, latitude: lat, longitude: lng);

/// In-memory account store with the backend's (kind, label) uniqueness.
class _FakeRemote implements SavedPlacesRemote {
  final List<SavedPlace> rows = [];
  bool offline = false;
  int _nextId = 1;

  void _check() {
    if (offline) throw Exception('offline');
  }

  @override
  Future<List<SavedPlace>> list() async {
    _check();
    return List.of(rows);
  }

  @override
  Future<SavedPlace> upsert(SavedPlace place) async {
    _check();
    final label = place.kind == SavedPlaceKind.custom ? place.label : '';
    final index = rows.indexWhere(
      (r) => r.kind == place.kind && r.label == label,
    );
    final saved = SavedPlace(
      id: index >= 0 ? rows[index].id : 'srv-${_nextId++}',
      kind: place.kind,
      label: label,
      name: place.name,
      secondaryText: place.secondaryText,
      latitude: place.latitude,
      longitude: place.longitude,
      savedAt: place.savedAt,
    );
    if (index >= 0) {
      rows[index] = saved;
    } else {
      rows.add(saved);
    }
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    _check();
    rows.removeWhere((r) => r.id == id);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SavedPlacesService with an account', () {
    test('saves shortcuts to the account', () async {
      final remote = _FakeRemote();
      final service = SavedPlacesService(userId: 'u1', remote: remote);

      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: '',
        location: _place('البيت'),
      );

      expect(remote.rows.single.name, 'البيت');
      expect((await service.shortcuts()).single.id, remote.rows.single.id);
    });

    test('shows places saved from another device', () async {
      final remote = _FakeRemote();
      await SavedPlacesService(userId: 'u1', remote: remote).saveShortcut(
        kind: SavedPlaceKind.work,
        label: '',
        location: _place('المكتب'),
      );

      // A fresh install: nothing cached on this device yet.
      SharedPreferences.setMockInitialValues({});
      final other = SavedPlacesService(userId: 'u1', remote: remote);

      expect((await other.shortcuts()).single.name, 'المكتب');
    });

    test('falls back to the cache when offline', () async {
      final remote = _FakeRemote();
      final service = SavedPlacesService(userId: 'u1', remote: remote);
      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: '',
        location: _place('البيت'),
      );

      remote.offline = true;

      expect((await service.shortcuts()).single.name, 'البيت');
    });

    test('a failed save changes nothing on the device', () async {
      final remote = _FakeRemote()..offline = true;
      final service = SavedPlacesService(userId: 'u1', remote: remote);

      await expectLater(
        service.saveShortcut(
          kind: SavedPlaceKind.home,
          label: '',
          location: _place('البيت'),
        ),
        throwsException,
      );
      expect(await service.shortcuts(), isEmpty);
    });

    test('removes a shortcut from the account', () async {
      final remote = _FakeRemote();
      final service = SavedPlacesService(userId: 'u1', remote: remote);
      await service.saveShortcut(
        kind: SavedPlaceKind.custom,
        label: 'النادي',
        location: _place('النادي'),
      );

      await service.removeShortcut(SavedPlaceKind.custom, label: 'النادي');

      expect(remote.rows, isEmpty);
      expect(await service.shortcuts(), isEmpty);
    });

    test('uploads places saved on the device before syncing, once', () async {
      // Saved while the device was the only store.
      await SavedPlacesService(userId: 'u1').saveShortcut(
        kind: SavedPlaceKind.custom,
        label: 'الجامعة',
        location: _place('الجامعة'),
      );
      final remote = _FakeRemote();
      final service = SavedPlacesService(userId: 'u1', remote: remote);

      await service.shortcuts();
      expect(remote.rows.single.label, 'الجامعة');

      // Deleted on another device afterwards: it must not come back.
      remote.rows.clear();
      expect(await service.shortcuts(), isEmpty);
    });

    test("keeps the account's copy over a stale device copy", () async {
      await SavedPlacesService(userId: 'u1').saveShortcut(
        kind: SavedPlaceKind.home,
        label: '',
        location: _place('البيت القديم'),
      );
      final remote = _FakeRemote();
      await remote.upsert(
        SavedPlace(
          kind: SavedPlaceKind.home,
          label: '',
          name: 'البيت الجديد',
          secondaryText: '',
          latitude: 32,
          longitude: 36,
          savedAt: DateTime.now(),
        ),
      );

      final service = SavedPlacesService(userId: 'u1', remote: remote);

      expect((await service.shortcuts()).single.name, 'البيت الجديد');
      expect(remote.rows, hasLength(1));
    });

    test('recents never leave the device', () async {
      final remote = _FakeRemote();
      final service = SavedPlacesService(userId: 'u1', remote: remote);

      await service.addRecent(_place('مكان'));
      await service.shortcuts();

      expect(remote.rows, isEmpty);
      expect((await service.recents()).single.name, 'مكان');
    });
  });
}
