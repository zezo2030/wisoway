import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/core/services/saved_places_service.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

LocationModel _place(String name, {double lat = 31.9, double lng = 35.9}) =>
    LocationModel(name: name, latitude: lat, longitude: lng);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SavedPlacesService', () {
    test('keeps recent places newest first', () async {
      final service = SavedPlacesService(userId: 'u1');

      await service.addRecent(_place('الأول', lat: 31.0));
      await service.addRecent(_place('الثاني', lat: 32.0));

      final recents = await service.recents();
      expect(recents.map((p) => p.name), ['الثاني', 'الأول']);
    });

    test('re-picking a place moves it up instead of duplicating it', () async {
      final service = SavedPlacesService(userId: 'u1');

      await service.addRecent(_place('الجامعة', lat: 32.0));
      await service.addRecent(_place('المستشفى', lat: 31.0));
      // Same spot as the first entry, a few metres off.
      await service.addRecent(_place('الجامعة', lat: 32.0001));

      final recents = await service.recents();
      expect(recents.length, 2);
      expect(recents.first.name, 'الجامعة');
    });

    test('caps the recent list', () async {
      final service = SavedPlacesService(userId: 'u1');

      for (var i = 0; i < SavedPlacesService.maxRecents + 5; i++) {
        await service.addRecent(_place('مكان $i', lat: 30 + i * 0.1));
      }

      final recents = await service.recents();
      expect(recents.length, SavedPlacesService.maxRecents);
      // The oldest entries were the ones dropped.
      expect(recents.map((p) => p.name), isNot(contains('مكان 0')));
    });

    test('never lists a shortcut twice under recents', () async {
      final service = SavedPlacesService(userId: 'u1');

      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: 'البيت',
        location: _place('شارع المدينة', lat: 31.5),
      );
      await service.addRecent(_place('شارع المدينة', lat: 31.5));

      expect(await service.recents(), isEmpty);
      expect((await service.shortcuts()).single.label, 'البيت');
    });

    test('replaces rather than duplicates the home shortcut', () async {
      final service = SavedPlacesService(userId: 'u1');

      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: 'البيت',
        location: _place('العنوان القديم', lat: 31.0),
      );
      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: 'البيت',
        location: _place('العنوان الجديد', lat: 32.0),
      );

      final shortcuts = await service.shortcuts();
      expect(shortcuts.length, 1);
      expect(shortcuts.single.name, 'العنوان الجديد');
    });

    test('lists shortcuts as home, then work, then custom', () async {
      final service = SavedPlacesService(userId: 'u1');

      await service.saveShortcut(
        kind: SavedPlaceKind.custom,
        label: 'النادي',
        location: _place('النادي', lat: 30.0),
      );
      await service.saveShortcut(
        kind: SavedPlaceKind.work,
        label: 'العمل',
        location: _place('المكتب', lat: 31.0),
      );
      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: 'البيت',
        location: _place('البيت', lat: 32.0),
      );

      expect((await service.shortcuts()).map((p) => p.label), [
        'البيت',
        'العمل',
        'النادي',
      ]);
    });

    test('keeps two accounts on one device separate', () async {
      final first = SavedPlacesService(userId: 'u1');
      final second = SavedPlacesService(userId: 'u2');

      await first.addRecent(_place('مكان خاص'));

      expect(await second.recents(), isEmpty);
      expect((await first.recents()).single.name, 'مكان خاص');
    });

    test('clearAll wipes only the signed-out account', () async {
      final first = SavedPlacesService(userId: 'u1');
      final second = SavedPlacesService(userId: 'u2');
      await first.addRecent(_place('مكان أول'));
      await second.addRecent(_place('مكان ثانٍ'));

      await first.clearAll();

      expect(await first.recents(), isEmpty);
      expect((await second.recents()).single.name, 'مكان ثانٍ');
    });

    test('clearRecents leaves shortcuts in place', () async {
      final service = SavedPlacesService(userId: 'u1');
      await service.saveShortcut(
        kind: SavedPlaceKind.home,
        label: 'البيت',
        location: _place('البيت', lat: 32.0),
      );
      await service.addRecent(_place('مكان', lat: 30.0));

      await service.clearRecents();

      expect(await service.recents(), isEmpty);
      expect((await service.shortcuts()).length, 1);
    });

    test('survives corrupted storage instead of blocking search', () async {
      SharedPreferences.setMockInitialValues({
        'saved_places:u1': 'not json at all',
      });
      final service = SavedPlacesService(userId: 'u1');

      expect(await service.recents(), isEmpty);
      await service.addRecent(_place('مكان جديد'));
      expect((await service.recents()).single.name, 'مكان جديد');
    });
  });
}
