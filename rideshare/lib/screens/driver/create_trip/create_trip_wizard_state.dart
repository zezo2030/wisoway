import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../models/location_model.dart';
import '../../../models/seat_layout_config.dart';
import '../../../models/trip_meeting_point.dart';
import '../../../models/vehicle_model.dart';
import '../../../utils/seat_layout_helpers.dart';

/// Shared, mutable state for the 3-step create-trip wizard.
///
/// The owning `State` object holds a single instance, mutates it from step
/// callbacks and calls `setState` afterwards, so this class deliberately stays
/// a plain data holder (no `ChangeNotifier`).
class CreateTripWizardState {
  CreateTripWizardState();

  /// Maximum number of intermediate stops allowed on a trip.
  static const int maxStops = 5;

  /// Index of the last wizard step (`0` route, `1` details, `2` review).
  static const int lastStepIndex = 2;

  static const List<String> weekdayKeys = [
    'sun',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
  ];

  // --- Step 0: route -------------------------------------------------------
  int stepIndex = 0;
  LocationModel? from;
  LocationModel? to;

  final List<LocationModel> stops = <LocationModel>[];
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  /// Exact pin where passengers gather, and the driver's description of it.
  /// Both are required: a meeting point is only agreed when it is findable.
  TripMeetingPoint? meetingPin;
  final TextEditingController meetingNoteController = TextEditingController();

  // --- Step 1: details -----------------------------------------------------
  /// Picked separately, so choosing a day never fills in a time the driver
  /// didn't choose; [departureTime] exists only once both are set.
  DateTime? departureDate;
  ({int hour, int minute})? departureClock;

  DateTime? get departureTime {
    final date = departureDate;
    final clock = departureClock;
    if (date == null || clock == null) return null;
    return DateTime(date.year, date.month, date.day, clock.hour, clock.minute);
  }

  /// Sets both halves at once (prefill, tests); null clears both.
  set departureTime(DateTime? value) {
    departureDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    departureClock = value == null
        ? null
        : (hour: value.hour, minute: value.minute);
  }

  SeatLayoutConfig? layout;
  /// Vehicle type key, used to pick the cabin artwork. Null when the driver has
  /// no vehicle on file, which falls back to the plain seat grid.
  String? vehicleType;
  /// Layout positions (1-based, front row first) the driver isn't offering.
  /// Ordered as closed, so "+" reopens the most recent one.
  final List<int> closedSeats = <int>[];

  /// Seats on offer: the layout minus what the driver closed.
  int get availableSeatCount =>
      maxLayoutSeats <= 0 ? 0 : maxLayoutSeats - closedSeats.length;

  /// Sets the count by closing (front seat first) or reopening seats.
  set availableSeatCount(int value) {
    final target = value.clamp(maxLayoutSeats > 0 ? 1 : 0, maxLayoutSeats);
    while (availableSeatCount > target && closeNextSeat()) {}
    while (availableSeatCount < target && closedSeats.isNotEmpty) {
      closedSeats.removeLast();
    }
  }
  bool preventGenderMixing = false;
  final TextEditingController priceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // --- Step 1: recurrence --------------------------------------------------
  bool enableRecurrence = false;
  String recurrenceFrequency = 'weekly'; // 'daily' | 'weekly'
  final Set<String> selectedWeekdays = <String>{};
  DateTime? recurrenceUntil;

  /// Passenger seats defined by the resolved layout (driver seat excluded).
  int get maxLayoutSeats {
    final config = layout;
    if (config == null) return 0;
    final list = config.seatsPerRowList;
    if (list != null && list.isNotEmpty) {
      return list.fold<int>(0, (sum, value) => sum + value);
    }
    return config.rows * config.seatsPerRow;
  }

  /// True when a seat layout could be resolved from the vehicle or its type.
  bool get hasLayout => layout != null && maxLayoutSeats > 0;

  bool get canAddStop => stops.length < maxStops;

  double? get price {
    final raw = priceController.text.trim();
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  String get notes => notesController.text.trim();

  String get meetingNote => meetingNoteController.text.trim();

  bool get hasMeetingPoint => meetingPin != null && meetingNote.isNotEmpty;

  /// The meeting point as sent to the API (pin + description).
  TripMeetingPoint? get meetingPoint =>
      hasMeetingPoint ? meetingPin!.copyWith(note: meetingNote) : null;

  /// Route step is complete once both endpoints and the meeting point are set.
  bool get canGoStep2 => from != null && to != null && hasMeetingPoint;

  /// Details step is complete with a departure time, a valid price and seats.
  bool get canGoStep3 =>
      departureTime != null && price != null && availableSeatCount >= 1;

  /// Publishing additionally requires a usable seat layout.
  bool get canPublish => canGoStep2 && canGoStep3 && hasLayout;

  /// Seeds layout-derived fields from the driver's vehicle, falling back to the
  /// vehicle-type [template] when the vehicle has no stored layout.
  void initFromVehicle(VehicleModel? vehicle, SeatLayoutConfig? template) {
    layout = vehicle?.seatLayout ?? template;
    vehicleType = vehicle?.vehicleType;
    closedSeats.clear();
    preventGenderMixing = layout?.preventGenderMixing ?? false;
  }

  /// Order "−" closes seats in: the front row first — the seat beside the
  /// driver is the one most often kept back — then from the rear forwards.
  List<int> get _closeOrder {
    final config = layout;
    if (config == null) return const [];
    final list = config.seatsPerRowList;
    final rows = list != null && list.isNotEmpty
        ? list
        : List<int>.filled(config.rows, config.seatsPerRow);
    final frontCount = rows.isEmpty ? 0 : rows.first;
    final all = List<int>.generate(maxLayoutSeats, (i) => i + 1);
    return [
      ...all.take(frontCount),
      ...all.skip(frontCount).toList().reversed,
    ];
  }

  /// Closes the next seat in [_closeOrder]; false when only one is left open.
  bool closeNextSeat() {
    if (availableSeatCount <= 1) return false;
    for (final seat in _closeOrder) {
      if (!closedSeats.contains(seat)) {
        closedSeats.add(seat);
        return true;
      }
    }
    return false;
  }

  /// Reopens the most recently closed seat.
  void reopenLastSeat() {
    if (closedSeats.isNotEmpty) closedSeats.removeLast();
  }

  /// Tapping a seat flips it, as long as at least one stays on offer.
  void toggleSeat(int position) {
    if (position < 1 || position > maxLayoutSeats) return;
    if (closedSeats.contains(position)) {
      closedSeats.remove(position);
    } else if (availableSeatCount > 1) {
      closedSeats.add(position);
    }
  }

  /// The closed seats as the API's seat ids (`row-col`).
  List<String> get closedSeatIds {
    final config = layout;
    if (config == null) return const [];
    return closedSeats
        .map((p) => SeatLayoutHelpers.displayIndexToBackendSeatId(p, config))
        .toList();
  }

  void addStop(LocationModel stop) {
    if (!canAddStop) return;
    stops.add(stop);
  }

  void removeStopAt(int index) {
    if (index < 0 || index >= stops.length) return;
    stops.removeAt(index);
  }

  void goToStep(int index) {
    if (index < 0 || index > lastStepIndex) return;
    stepIndex = index;
  }

  /// Recurrence payload for the create-trip API (null when disabled).
  Map<String, dynamic>? buildRecurrencePayload() {
    if (!enableRecurrence) return null;
    return <String, dynamic>{
      'frequency': recurrenceFrequency,
      if (recurrenceFrequency == 'weekly' && selectedWeekdays.isNotEmpty)
        'weekdays': selectedWeekdays.toList(),
      if (recurrenceUntil != null)
        'until': DateFormat('yyyy-MM-dd').format(recurrenceUntil!),
    };
  }

  void dispose() {
    fromController.dispose();
    toController.dispose();
    meetingNoteController.dispose();
    priceController.dispose();
    notesController.dispose();
  }
}
