import '../../models/rating_model.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';

class RatingService {
  final ApiClient _api = ApiClient();

  /// هل قام المستخدم الحالي بتقييم الرحلة؟
  Future<bool> hasUserRatedTrip(String tripId) async {
    final list = await getMyGivenRatings();
    return list.any((r) => r.tripId == tripId);
  }

  /// نفس rateUser (للتوافق مع الشاشات).
  Future<RatingModel> createRating({
    required String toUserId,
    required String tripId,
    required int rating,
    String? comment,
  }) =>
      rateUser(toUserId: toUserId, tripId: tripId, rating: rating, comment: comment);

  // Rate a user (driver rates passenger OR passenger rates driver)
  Future<RatingModel> rateUser({
    required String toUserId,
    required String tripId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.ratings,
        data: {
          'toUserId': toUserId,
          'tripId': tripId,
          'rating': rating,
          'comment': comment,
        },
      );

      final data = response['data'] ?? response;
      return RatingModel.fromJson(data);
    } catch (e) {
      print('❌ Error rating user: $e');
      rethrow;
    }
  }

  static List<RatingModel> _ratingsListFromResponse(dynamic response) {
    final raw = response is Map ? (response['data'] ?? response) : response;
    if (raw is List) {
      return raw
          .map((e) => RatingModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (raw is Map) {
      final inner = raw['data'] ?? raw['items'];
      if (inner is List) {
        return inner
            .map((e) =>
                RatingModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    return [];
  }

  // Get ratings FOR a specific user
  Future<List<RatingModel>> getUserRatings(String userId) async {
    try {
      final response = await _api.get(ApiEndpoints.userRatings(userId));
      return _ratingsListFromResponse(response);
    } catch (e) {
      print('❌ Error getting user ratings: $e');
      return [];
    }
  }

  // Get ratings CREATED BY current logged in user
  Future<List<RatingModel>> getMyGivenRatings() async {
    try {
      final response = await _api.get(ApiEndpoints.myRatings);
      return _ratingsListFromResponse(response);
    } catch (e) {
      print('❌ Error getting my ratings: $e');
      return [];
    }
  }

  // Get ratings for a specific trip
  Future<List<RatingModel>> getTripRatings(String tripId) async {
    try {
      final response = await _api.get(ApiEndpoints.tripRatings(tripId));
      return _ratingsListFromResponse(response);
    } catch (e) {
      print('❌ Error getting trip ratings: $e');
      return [];
    }
  }
}
