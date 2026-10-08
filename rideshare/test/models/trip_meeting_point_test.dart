import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare/models/location_model.dart';
import 'package:rideshare/models/trip_meeting_point.dart';
import 'package:rideshare/models/trip_model.dart';
import 'package:rideshare/screens/driver/create_trip/create_trip_wizard_state.dart';

void main() {
  test('a trip carries its meeting point from the API', () {
    final json = {
      'id': 't-1',
      'driverId': 'd-1',
      'fromName': 'Al Ula Old town',
      'toName': 'Medina',
      'departureTime': '2026-10-01T10:00:00Z',
      'price': '5.00',
      'meetingPoint': {
        'lat': '26.61',
        'lng': 37.92,
        'address': 'Old town gate',
        'note': 'عند الدوار، أمام صيدلية النور',
      },
    };

    final mp = TripModel.fromJson(json).meetingPoint!;
    expect(mp.latitude, 26.61);
    expect(mp.longitude, 37.92);
    expect(mp.note, 'عند الدوار، أمام صيدلية النور');

    json.remove('meetingPoint');
    expect(TripModel.fromJson(json).meetingPoint, isNull);
  });

  test('the route step needs a pinned and described meeting point', () {
    final wizard = CreateTripWizardState()
      ..from = LocationModel(name: 'A', latitude: 26.6, longitude: 37.9)
      ..to = LocationModel(name: 'B', latitude: 24.5, longitude: 39.6);
    addTearDown(wizard.dispose);

    expect(wizard.canGoStep2, isFalse);

    wizard.meetingPin = const TripMeetingPoint(
      latitude: 26.61,
      longitude: 37.92,
      address: 'Old town gate',
    );
    expect(wizard.canGoStep2, isFalse, reason: 'no description yet');

    wizard.meetingNoteController.text = '  أمام صيدلية النور ';
    expect(wizard.canGoStep2, isTrue);
    expect(wizard.meetingPoint!.toJson(), {
      'lat': 26.61,
      'lng': 37.92,
      'address': 'Old town gate',
      'note': 'أمام صيدلية النور',
    });
  });
}
