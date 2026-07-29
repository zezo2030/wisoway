import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../models/location_model.dart';
import '../../../models/seat_layout_config.dart';
import '../../../models/vehicle_model.dart';

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

  // --- Step 1: details -----------------------------------------------------
  DateTime? departureTime;
  SeatLayoutConfig? layout;
  int availableSeatCount = 0;
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

  /// Route step is complete once both endpoints are picked.
  bool get canGoStep2 => from != null && to != null;

  /// Details step is complete with a departure time, a valid price and seats.
  bool get canGoStep3 =>
      departureTime != null && price != null && availableSeatCount >= 1;

  /// Publishing additionally requires a usable seat layout.
  bool get canPublish => canGoStep2 && canGoStep3 && hasLayout;

  /// Keeps [availableSeatCount] inside `1..maxLayoutSeats` (0 when no layout).
  void clampAvailableSeats() {
    final max = maxLayoutSeats;
    if (max <= 0) {
      availableSeatCount = 0;
      return;
    }
    if (availableSeatCount < 1) {
      availableSeatCount = 1;
    } else if (availableSeatCount > max) {
      availableSeatCount = max;
    }
  }

  /// Seeds layout-derived fields from the driver's vehicle, falling back to the
  /// vehicle-type [template] when the vehicle has no stored layout.
  void initFromVehicle(VehicleModel? vehicle, SeatLayoutConfig? template) {
    layout = vehicle?.seatLayout ?? template;
    availableSeatCount = maxLayoutSeats;
    preventGenderMixing = layout?.preventGenderMixing ?? false;
  }

  void setAvailableSeatCount(int value) {
    availableSeatCount = value;
    clampAvailableSeats();
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
    priceController.dispose();
    notesController.dispose();
  }
}
