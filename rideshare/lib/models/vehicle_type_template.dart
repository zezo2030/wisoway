import 'seat_layout_config.dart';

class VehicleTypeTemplate {
  final String type;
  final Map<String, String> label;
  final int seats;
  final SeatLayoutConfig layout;

  const VehicleTypeTemplate({
    required this.type,
    required this.label,
    required this.seats,
    required this.layout,
  });

  factory VehicleTypeTemplate.fromJson(Map<String, dynamic> json) {
    final rawLabel = json['label'];
    final rawLayout = json['layout'];

    return VehicleTypeTemplate(
      type: json['type']?.toString() ?? '',
      label: rawLabel is Map
          ? rawLabel.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      seats: json['seats'] is int
          ? json['seats'] as int
          : int.tryParse(json['seats']?.toString() ?? '') ?? 0,
      layout: rawLayout is Map
          ? SeatLayoutConfig.fromMap(Map<String, dynamic>.from(rawLayout))
          : SeatLayoutConfig(rows: 1, seatsPerRow: 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'label': label,
      'seats': seats,
      'layout': layout.toMap(),
    };
  }

  String localizedLabel(String languageCode) {
    return label[languageCode] ?? label['en'] ?? type;
  }
}
