import 'dart:io';
import 'package:dio/dio.dart';
import '../../models/vehicle_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class VehicleService {
  final ApiClient _api = ApiClient();

  // Create a vehicle
  Future<VehicleModel> addVehicle({
    required String driverId,
    required String vehicleType,
    required String plateNumber,
    required String modelName,
    required int seats,
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

      final response = await _api.post(
        ApiEndpoints.vehicles,
        data: {
          'vehicleType': vehicleType,
          'plateNumber': plateNumber,
          'model': modelName,
          'seats': seats,
          'licenseImageUrl': licenseImageUrl,
          'vehicleLicenseImageUrl': vehicleLicenseImageUrl,
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
      // If 404, the user doesn't have a vehicle
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    } catch (e) {
      print('❌ Error getting vehicle: $e');
      return null;
    }
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
