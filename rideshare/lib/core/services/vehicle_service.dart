import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/vehicle_model.dart';
import '../../models/seat_layout_config.dart';
import '../../models/vehicle_type_template.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class VehicleService {
  static const String _vehicleTypesCacheKey = 'vehicle_type_templates';
  final ApiClient _api = ApiClient();

  Future<List<VehicleTypeTemplate>> getVehicleTypes({
    bool allowCachedFallback = true,
  }) async {
    try {
      final response = await _api.get(ApiEndpoints.vehicleTypes);
      final data = response['data'] ?? response;
      final rawTypes = data['types'];
      final types = rawTypes is List
          ? rawTypes
                .whereType<Map>()
                .map((item) => VehicleTypeTemplate.fromJson(
                      Map<String, dynamic>.from(item),
                    ))
                .where((item) => item.type.isNotEmpty)
                .toList()
          : <VehicleTypeTemplate>[];

      if (types.isNotEmpty) {
        await _cacheVehicleTypes(types);
      }
      return types;
    } catch (e) {
      if (!allowCachedFallback) rethrow;
      final cached = await getCachedVehicleTypes();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<VehicleTypeTemplate>> getCachedVehicleTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vehicleTypesCacheKey);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((item) => VehicleTypeTemplate.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.type.isNotEmpty)
        .toList();
  }

  Future<void> _cacheVehicleTypes(List<VehicleTypeTemplate> types) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vehicleTypesCacheKey,
      jsonEncode(types.map((item) => item.toJson()).toList()),
    );
  }

  // Create a vehicle
  Future<VehicleModel> addVehicle({
    required String driverId,
    required String vehicleType,
    required String plateNumber,
    required String modelName,
    required int seats,
    required File carImage,
    SeatLayoutConfig? seatLayout,
    File? licenseImage,
    File? vehicleLicenseImage,
  }) async {
    try {
      String? licenseImageUrl;
      String? vehicleLicenseImageUrl;

      if (licenseImage != null) {
        licenseImageUrl = await uploadFile(licenseImage);
      }

      if (vehicleLicenseImage != null) {
        vehicleLicenseImageUrl = await uploadFile(vehicleLicenseImage);
      }

      final carImageUrl = await uploadFile(carImage);

      final response = await _api.post(
        ApiEndpoints.vehicles,
        data: {
          'vehicleType': vehicleType,
          'plateNumber': plateNumber,
          'model': modelName,
          'seats': seats,
          if (seatLayout != null) 'seatLayout': seatLayout.toMap(),
          'licenseImageUrl': licenseImageUrl,
          'vehicleLicenseImageUrl': vehicleLicenseImageUrl,
          'carImageUrl': carImageUrl,
        },
      );

      final data = response['data'] ?? response;
      return VehicleModel.fromJson(data);
    } catch (e) {
      print('❌ Error adding vehicle: $e');
      rethrow;
    }
  }

  // Get driver's own vehicle
  Future<VehicleModel?> getMyVehicle() async {
    try {
      final response = await _api.get(ApiEndpoints.myVehicle);
      final data = response['data'] ?? response;
      return VehicleModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    } catch (e) {
      print('❌ Error getting vehicle: $e');
      return null;
    }
  }

  // Update the driver's vehicle (currently only seatLayout is editable
  // post-registration, but the endpoint accepts any subset of fields).
  Future<VehicleModel> updateVehicle(
    String vehicleId, {
    String? vehicleType,
    int? seats,
    SeatLayoutConfig? seatLayout,
  }) async {
    final body = <String, dynamic>{
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (seats != null) 'seats': seats,
      if (seatLayout != null) 'seatLayout': seatLayout.toMap(),
    };

    final response = await _api.patch(
      ApiEndpoints.vehicleById(vehicleId),
      data: body,
    );
    final data = response['data'] ?? response;
    return VehicleModel.fromJson(data);
  }

  // Helper method for file uploads
  Future<String> uploadFile(File file) async {
    try {
      final fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _api.post(ApiEndpoints.uploads, data: formData);
      return response['url'] ?? response['data']['url'];
    } catch (e) {
      throw Exception('فشل في رفع صورة السيارة/الرخصة');
    }
  }
}
