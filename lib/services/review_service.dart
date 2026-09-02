import 'package:http/http.dart' as http;
import 'dart:convert';

class ReviewService {
  static const String baseUrl = 'https://mysalecentra.com/api';

  static Future<Map<String, dynamic>> getShopReviews(String userId, String shopSlug, {int page = 1, int perPage = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/storefront/reviews/shop/$shopSlug?user_id=$userId&page=$page&per_page=$perPage'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to load reviews');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<void> deleteReview(String userId, String reviewId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/storefront/reviews/$reviewId?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}
