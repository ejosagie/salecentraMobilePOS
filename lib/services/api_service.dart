import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Change this to your VPS IP/domain
  // For testing: http://161.35.166.245:5000/api
  // For production with SSL: https://mysalecentra.com/api
  static const String baseUrl = 'https://mysalecentra.com/api';
  
  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.body.trim().startsWith('<')) {
        throw Exception('Server returned HTML (${response.statusCode}). Check that baseUrl is correct and the API endpoint exists.');
      }

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Request failed');
      }
    } on SocketException catch (_) {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException catch (_) {
      throw Exception('Unable to reach the server. Please try again later.');
    } on FormatException catch (_) {
      throw Exception('Invalid response from server. Please contact support.');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: params);
      
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.body.trim().startsWith('<')) {
        throw Exception('Server returned HTML (${response.statusCode}). Check that baseUrl is correct and the API endpoint exists.');
      }

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Request failed');
      }
    } on SocketException catch (_) {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException catch (_) {
      throw Exception('Unable to reach the server. Please try again later.');
    } on FormatException catch (_) {
      throw Exception('Invalid response from server. Please contact support.');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 30));

      if (response.body.trim().startsWith('<')) {
        throw Exception('Server returned HTML (${response.statusCode}). Check that baseUrl is correct and the API endpoint exists.');
      }

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Request failed');
      }
    } on SocketException catch (_) {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException catch (_) {
      throw Exception('Unable to reach the server. Please try again later.');
    } on FormatException catch (_) {
      throw Exception('Invalid response from server. Please contact support.');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
      ).timeout(const Duration(seconds: 30));

      if (response.body.trim().startsWith('<')) {
        throw Exception('Server returned HTML (${response.statusCode}). Check that baseUrl is correct and the API endpoint exists.');
      }

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Request failed');
      }
    } on SocketException catch (_) {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException catch (_) {
      throw Exception('Unable to reach the server. Please try again later.');
    } on FormatException catch (_) {
      throw Exception('Invalid response from server. Please contact support.');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(String endpoint, File file, Map<String, String> fields) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'));
      request.fields.addAll(fields);
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        file.path,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.body.trim().startsWith('<')) {
        throw Exception('Server returned HTML (${response.statusCode}). Check that baseUrl is correct and the API endpoint exists.');
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        throw Exception(responseData['error'] ?? 'Upload failed');
      }
    } on SocketException catch (_) {
      throw Exception('No internet connection. Please check your network and try again.');
    } on HttpException catch (_) {
      throw Exception('Unable to reach the server. Please try again later.');
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }
}
