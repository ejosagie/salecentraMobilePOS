import 'package:http/http.dart' as http;
import 'dart:convert';

class DeliveryService {
  static const String baseUrl = 'https://mysalecentra.com/api';

  static Future<Map<String, dynamic>> getProviders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/deliveries/providers'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to load providers');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> searchAddress(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/search-address'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Address search failed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> estimateDelivery({
    required String userId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> dropoff,
    required String provider,
    String state = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/estimate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'pickup': pickup,
          'dropoff': dropoff,
          'provider': provider,
          'state': state,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Estimate failed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> bookDelivery({
    required String userId,
    required Map<String, dynamic> pickup,
    required Map<String, dynamic> dropoff,
    required String provider,
    required double riderCost,
    String? customerId,
    String? saleId,
    String notes = '',
    String state = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/book'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'pickup': pickup,
          'dropoff': dropoff,
          'provider': provider,
          'rider_cost': riderCost,
          if (customerId != null) 'customer_id': customerId,
          if (saleId != null) 'sale_id': saleId,
          'notes': notes,
          'state': state,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }
      throw Exception(data['error'] ?? 'Booking failed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> listDeliveries({
    required String userId,
    String? statusFilter,
  }) async {
    try {
      final params = {'user_id': userId};
      if (statusFilter != null) params['status'] = statusFilter;

      final uri = Uri.parse('$baseUrl/deliveries').replace(queryParameters: params);
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to load deliveries');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getDelivery(String deliveryId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/deliveries/$deliveryId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to load delivery');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> cancelDelivery(String deliveryId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/$deliveryId/cancel'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Cancel failed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> initiatePayment({
    required String deliveryId,
    required String email,
    String customerName = 'Customer',
    String customerPhone = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/payment/initiate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'delivery_id': deliveryId,
          'email': email,
          'customer_name': customerName,
          'customer_phone': customerPhone,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Payment initiation failed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> verifyPayment({
    required String txRef,
    String? transactionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deliveries/payment/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tx_ref': txRef,
          if (transactionId != null) 'transaction_id': transactionId,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Payment verification failed');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
