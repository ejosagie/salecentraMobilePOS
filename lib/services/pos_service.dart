import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class PosService {
  static const String _baseUrl = ApiService.baseUrl;

  static Future<Map<String, dynamic>> checkPosStatus(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pos/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to check POS status');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> registerTerminal(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pos/register-terminal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to register terminal');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<bool> saveBankDetails({
    required String userId,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/pos/bank-details'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_name': accountName,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getBankDetails(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/pos/bank-details?user_id=$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
