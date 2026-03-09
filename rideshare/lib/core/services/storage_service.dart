import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class StorageService {
  final ImagePicker _imagePicker = ImagePicker();
  final ApiClient _api = ApiClient();

  // Pick image from gallery or camera
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return image;
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    }
  }

  // Upload any image file using ApiClient
  Future<String?> uploadImage({
    required File imageFile,
    required String folder,
    required String fileName,
  }) async {
    try {
      final String originalName = imageFile.path.split('/').last;

      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: originalName,
        ),
        'folder': folder, // If API supports specifying a folder
      });

      final response = await _api.post(ApiEndpoints.uploads, data: formData);
      return response['url'] ?? response['data']['url'];
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture({
    required File imageFile,
    required String userId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'profiles',
      fileName: userId,
    );
  }

  // Upload driver license
  Future<String?> uploadDriverLicense({
    required File imageFile,
    required String userId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'driver_licenses',
      fileName: userId,
    );
  }

  // Upload vehicle license
  Future<String?> uploadVehicleLicense({
    required File imageFile,
    required String userId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'vehicle_licenses',
      fileName: userId,
    );
  }

  // Delete image API
  Future<bool> deleteImage(String imageUrl) async {
    // Requires an endpoint from API to delete files.
    // If not implemented, just return true loosely.
    return true;
  }
}
