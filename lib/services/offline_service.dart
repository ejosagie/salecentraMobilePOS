import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }

  static Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}

class OfflineAuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _sessionKey = 'pos_offline_session';
  static const Duration _maxOfflineDuration = Duration(days: 3);

  static Future<void> cacheSession(Map<String, dynamic> userData) async {
    final session = {
      'user': userData,
      'cached_at': DateTime.now().toIso8601String(),
    };
    await _storage.write(key: _sessionKey, value: jsonEncode(session));
  }

  static Future<Map<String, dynamic>?> getCachedSession() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null) return null;
      final session = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(session['cached_at'] as String);
      final elapsed = DateTime.now().difference(cachedAt);
      if (elapsed > _maxOfflineDuration) {
        await _storage.delete(key: _sessionKey);
        return null;
      }
      return session['user'] as Map<String, dynamic>?;
    } catch (e) {
      if (kDebugMode) print('[OfflineAuth] Error: $e');
      return null;
    }
  }

  static Future<int> getOfflineDaysRemaining() async {
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null) return 0;
      final session = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(session['cached_at'] as String);
      final elapsed = DateTime.now().difference(cachedAt);
      final remaining = _maxOfflineDuration - elapsed;
      return remaining.inDays;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
