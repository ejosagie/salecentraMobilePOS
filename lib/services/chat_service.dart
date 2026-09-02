import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';

class ChatService {
  static const String baseUrl = 'https://mysalecentra.com/api';

  static Future<Map<String, dynamic>> getConversations(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/storefront/chat/conversations?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to load conversations');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getMessages(String conversationId, String? userId) async {
    try {
      String url = '$baseUrl/storefront/chat/messages?conversation_id=$conversationId';
      if (userId != null) {
        url += '&user_id=$userId';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to load messages');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> sendReply({
    required String userId,
    required String conversationId,
    required String message,
    String messageType = 'text',
    String? imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/storefront/chat/merchant-reply'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'conversation_id': conversationId,
          'message': message,
          'message_type': messageType,
          'image_url': imageUrl,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return data;
      }
      throw Exception(data['error'] ?? 'Failed to send message');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<int> getUnreadCount(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/storefront/chat/unread-count?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['unread_count'] as int;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> markRead(String userId, String conversationId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/storefront/chat/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'conversation_id': conversationId,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<void> markUnread(String userId, String conversationId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/storefront/chat/mark-unread'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'conversation_id': conversationId,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<void> deleteConversation(String userId, String conversationId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/storefront/chat/conversation/$conversationId?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static Future<String?> uploadMedia(String userId, String conversationId, File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/storefront/chat/upload-media'),
      );
      request.fields['user_id'] = userId;
      request.fields['conversation_id'] = conversationId;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return data['image_url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
