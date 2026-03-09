import 'dart:io';
import 'package:dio/dio.dart';
import '../../models/payment_model.dart';
import '../../models/wallet_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class PaymentService {
  final ApiClient _api = ApiClient();

  // Create standard payment (For passenger paying driver or vice versa via manual/Stripe)
  Future<PaymentModel> createPayment({
    String? tripId,
    String? bookingId,
    required double amount,
    required String currency,
    required PaymentMethod method,
    String? walletNumber,
    String? transactionId,
    File? proofImage,
  }) async {
    try {
      String? proofImageUrl;

      // Upload proof image if exists
      if (proofImage != null && method == PaymentMethod.manual) {
        proofImageUrl = await uploadFile(proofImage);
      }

      final response = await _api.post(
        ApiEndpoints.payments,
        data: {
          'tripId': tripId,
          'bookingId': bookingId,
          'amount': amount,
          'currency': currency,
          'method': method.name,
          'walletNumber': walletNumber,
          'transactionId': transactionId,
          'proofImageUrl': proofImageUrl,
        },
      );

      final data = response['data'] ?? response;
      return PaymentModel.fromJson(data);
    } catch (e) {
      print('❌ Error creating payment: $e');
      rethrow;
    }
  }

  // Pay communication fee (Driver paying to unlock passenger details)
  Future<PaymentModel> payCommunicationFee({
    required String bookingId,
    required PaymentMethod method,
    String? walletNumber,
    String? transactionId,
    File? proofImage,
  }) async {
    try {
      String? proofImageUrl;

      // Upload proof image if exists
      if (proofImage != null && method == PaymentMethod.manual) {
        proofImageUrl = await uploadFile(proofImage);
      }

      final response = await _api.post(
        ApiEndpoints.communicationFee,
        data: {
          'bookingId': bookingId,
          'method': method.name,
          'walletNumber': walletNumber,
          'transactionId': transactionId,
          'proofImageUrl': proofImageUrl,
        },
      );

      final data = response['data'] ?? response;
      return PaymentModel.fromJson(data);
    } catch (e) {
      print('❌ Error paying communication fee: $e');
      rethrow;
    }
  }

  /// جلب دفعة واحدة بالمعرف.
  Future<PaymentModel?> getPayment(String paymentId) async {
    try {
      final response = await _api.get(ApiEndpoints.paymentById(paymentId));
      final data = response['data'] ?? response;
      return PaymentModel.fromJson(data);
    } catch (e) {
      print('❌ Error getting payment: $e');
      return null;
    }
  }

  /// رفع صورة إثبات الدفع (نفس uploadFile).
  Future<String> uploadProofImage(File file) => uploadFile(file);

  /// تحديث دفعة يدوية (رفع إثبات أو بيانات).
  Future<PaymentModel> updateManualPayment(
    String paymentId, {
    String? proofImageUrl,
    String? walletNumber,
    String? transactionId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (proofImageUrl != null) data['proofImageUrl'] = proofImageUrl;
      if (walletNumber != null) data['walletNumber'] = walletNumber;
      if (transactionId != null) data['transactionId'] = transactionId;
      final response =
          await _api.patch(ApiEndpoints.paymentById(paymentId), data: data);
      final res = response['data'] ?? response;
      return PaymentModel.fromJson(res);
    } catch (e) {
      print('❌ Error updating manual payment: $e');
      rethrow;
    }
  }

  /// تيار قائمة المدفوعات (استدعاء دوري).
  Stream<List<PaymentModel>> getPaymentHistoryStream() async* {
    while (true) {
      yield await getMyPayments();
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  /// Driver wallet: get balance and free-trip status
  Future<WalletModel> getWalletMe() async {
    final response = await _api.get(ApiEndpoints.walletMe);
    final data = response['data'] ?? response;
    return WalletModel.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Driver wallet: paginated transactions (top-ups and trip charges)
  Future<Map<String, dynamic>> getWalletTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      ApiEndpoints.walletTransactions,
      queryParameters: {'page': page, 'limit': limit},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Driver wallet: create top-up request (pending until admin approves)
  Future<PaymentModel> createWalletTopup({
    required double amount,
    String currency = 'EGP',
    required String method,
    String? proofImageUrl,
    File? proofImage,
    String? walletNumber,
  }) async {
    String? url = proofImageUrl;
    if (url == null && proofImage != null && method == 'manual') {
      url = await uploadFile(proofImage);
    }
    final data = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'method': method,
    };
    if (url != null) data['proofImageUrl'] = url;
    if (walletNumber != null) data['walletNumber'] = walletNumber;
    final response = await _api.post(ApiEndpoints.walletTopup, data: data);
    final res = response['data'] ?? response;
    return PaymentModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  // Get user payments
  Future<List<PaymentModel>> getMyPayments() async {
    try {
      final response = await _api.get(ApiEndpoints.myPayments);
      final data = response['data'] as List? ?? [];
      return data.map((json) => PaymentModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error getting payments: $e');
      return [];
    }
  }

  // Initiate CliQ A2A communication fee
  Future<PaymentModel> initiateCliqCommunicationFee({
    required String bookingId,
    required String aliasType, // 'ALIAS' or 'MOBL'
    required String aliasValue,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.cliqInitiate,
        data: {
          'bookingId': bookingId,
          'aliasType': aliasType,
          'aliasValue': aliasValue,
        },
      );

      final data = response['data'] ?? response;
      return PaymentModel.fromJson(data);
    } catch (e) {
      print('❌ Error initiating CliQ payment: $e');
      rethrow;
    }
  }

  // Refresh CliQ payment status
  Future<PaymentModel> refreshCliqPaymentStatus(String paymentId) async {
    try {
      final response =
          await _api.get(ApiEndpoints.cliqStatus(paymentId));
      final data = response['data'] ?? response;
      return PaymentModel.fromJson(data);
    } catch (e) {
      print('❌ Error refreshing CliQ payment status: $e');
      rethrow;
    }
  }

  // Approve payment - Requires Admin
  Future<void> approvePayment(String paymentId) async {
    try {
      await _api.patch(ApiEndpoints.approvePayment(paymentId));
    } catch (e) {
      print('❌ Error approving payment: $e');
      rethrow;
    }
  }

  // Reject payment - Requires Admin
  Future<void> rejectPayment(String paymentId, {String? adminNote}) async {
    try {
      await _api.patch(
        ApiEndpoints.rejectPayment(paymentId),
        data: {'adminNote': adminNote},
      );
    } catch (e) {
      print('❌ Error rejecting payment: $e');
      rethrow;
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
      throw Exception('فشل في رفع الصورة');
    }
  }
}
