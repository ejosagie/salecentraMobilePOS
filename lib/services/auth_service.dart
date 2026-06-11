import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static const String _currentUserKey = 'current_user';
  static const String _isStaffLoginKey = 'is_staff_login';
  static const String _staffNameKey = 'staff_name';
  static const String _lastActivityKey = 'last_activity';
  static const int _sessionTimeoutMinutes = 30;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> register({
    required String email,
    required String password,
    required String businessName,
    required String businessAddress,
    required String phoneNumber,
    required String contactPerson,
    required String industry,
    required String country,
    String currency = 'NGN',
  }) async {
    final response = await ApiService.post('/auth/register', {
      'email': email,
      'password': password,
      'business_name': businessName,
      'business_address': businessAddress,
      'phone_number': phoneNumber,
      'contact_person': contactPerson,
      'industry': industry,
      'country': country,
    });

    if (response['success']) {
      // Create user object from response
      final user = User(
        id: response['user_id'],
        email: email,
        passwordHash: _hashPassword(password),
        businessName: businessName,
        businessAddress: businessAddress,
        phoneNumber: phoneNumber,
        contactPerson: contactPerson,
        industry: industry,
        country: country,
        currency: currency,
        trialEnd: DateTime.parse(response['trial_end']),
        subscriptionStatus: 'trial',
        onboardingComplete: false,
      );

      await _saveCurrentUser(user);
      await updateLastActivity();
      return user;
    }
    throw Exception(response['error'] ?? 'Registration failed');
  }

  Future<User?> login(String email, String password) async {
    final response = await ApiService.post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (response['success']) {
      final userData = response['user'];
      final user = User(
        id: userData['id'],
        email: userData['email'],
        passwordHash: _hashPassword(password),
        businessName: userData['business_name'],
        businessAddress: userData['business_address'],
        phoneNumber: userData['phone_number'],
        contactPerson: userData['contact_person'],
        industry: userData['industry'],
        country: userData['country'],
        currency: userData['currency'],
        trialStart: userData['trial_start'] != null ? DateTime.tryParse(userData['trial_start']) : null,
        trialEnd: userData['trial_end'] != null ? DateTime.tryParse(userData['trial_end']) : null,
        subscriptionStatus: userData['subscription_status'],
        subscriptionStart: userData['subscription_start'] != null ? DateTime.tryParse(userData['subscription_start']) : null,
        subscriptionEnd: userData['subscription_end'] != null ? DateTime.tryParse(userData['subscription_end']) : null,
        onboardingComplete: userData['onboarding_complete'],
        logoBase64: userData['logo_base64'],
        salesEntryEnabled: userData['sales_entry_enabled'],
        salesEntryStaffName: userData['sales_entry_staff_name'],
      );

      await _saveCurrentUser(user);
      await updateLastActivity();
      return user;
    }
    throw Exception(response['error'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>?> staffLogin({
    required String email,
    required String staffName,
    required String password,
  }) async {
    final response = await ApiService.post('/auth/staff-login', {
      'email': email,
      'staff_name': staffName,
      'password': password,
    });

    if (response['success']) {
      final userData = response['user'];
      final user = User(
        id: userData['id'],
        email: userData['email'],
        passwordHash: userData['password_hash'] ?? '',
        businessName: userData['business_name'],
        businessAddress: userData['business_address'] ?? '',
        phoneNumber: userData['phone_number'] ?? '',
        contactPerson: userData['contact_person'] ?? '',
        industry: userData['industry'] ?? '',
        country: userData['country'] ?? '',
        currency: userData['currency'] ?? 'NGN',
        salesEntryStaffName: userData['staff_name'],
      );

      await _saveCurrentUser(user, isStaffLogin: true, staffName: staffName);
      await updateLastActivity();
      return {
        'user': user,
        'staffName': staffName,
      };
    }
    throw Exception(response['error'] ?? 'Staff login failed');
  }

  Future<void> saveCurrentUser(User user, {bool isStaffLogin = false, String? staffName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentUserKey, jsonEncode(user.toMap()));
    await prefs.setBool(_isStaffLoginKey, isStaffLogin);
    if (staffName != null) {
      await prefs.setString(_staffNameKey, staffName);
    }
  }

  Future<void> _saveCurrentUser(User user, {bool isStaffLogin = false, String? staffName}) async {
    await saveCurrentUser(user, isStaffLogin: isStaffLogin, staffName: staffName);
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    
    try {
      return User.fromMap(jsonDecode(userJson));
    } catch (e) {
      return null;
    }
  }

  Future<bool> isStaffLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isStaffLoginKey) ?? false;
  }

  Future<String?> getStaffName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_staffNameKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
    await prefs.remove(_isStaffLoginKey);
    await prefs.remove(_staffNameKey);
  }

  Future<bool> isLoggedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActivityKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivity = prefs.getInt(_lastActivityKey);
    if (lastActivity == null) return false;
    final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastActivity));
    return elapsed.inMinutes > _sessionTimeoutMinutes;
  }

  Future<void> logoutIfExpired() async {
    if (await isSessionExpired()) {
      await logout();
    }
  }

  Future<User> getBusinessProfile(String userId) async {
    final response = await ApiService.get('/settings/profile', params: {'user_id': userId});
    if (response['success']) {
      final user = User.fromMap(response['user']);
      await _saveCurrentUser(user, isStaffLogin: false);
      return user;
    }
    throw Exception(response['error'] ?? 'Failed to fetch business profile');
  }

  Future<User> updateBusinessProfile({
    required String userId,
    required String businessName,
    required String businessAddress,
    required String phoneNumber,
    required String contactPerson,
    required String industry,
    required String country,
    String? logoBase64,
    String? currency,
  }) async {
    final payload = {
      'user_id': userId,
      'business_name': businessName,
      'business_address': businessAddress,
      'phone_number': phoneNumber,
      'contact_person': contactPerson,
      'industry': industry,
      'country': country,
    };
    if (logoBase64 != null && logoBase64.isNotEmpty) {
      payload['logo_base64'] = logoBase64;
    }
    if (currency != null && currency.isNotEmpty) {
      payload['currency'] = currency;
    }
    final response = await ApiService.put('/settings/profile', payload);

    if (response['success']) {
      final user = User.fromMap(response['user']);
      await _saveCurrentUser(user, isStaffLogin: false);
      return user;
    }
    throw Exception(response['error'] ?? 'Failed to update business profile');
  }

  Future<void> completeOnboarding(String userId) async {
    final response = await ApiService.post('/auth/complete-onboarding', {'user_id': userId});
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to complete onboarding');
    }
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await ApiService.post('/settings/change-password', {
      'user_id': userId,
      'current_password': currentPassword,
      'new_password': newPassword,
    });

    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to change password');
    }
  }

  Future<Map<String, dynamic>> getStaffSettings(String userId) async {
    final response = await ApiService.get('/settings/staff', params: {'user_id': userId});
    if (response['success']) {
      return {
        'enabled': response['enabled'] == true,
        'staff_name': response['staff_name']?.toString(),
      };
    }
    throw Exception(response['error'] ?? 'Failed to fetch staff settings');
  }

  Future<void> updateSalesEntrySettings({
    required String userId,
    required bool enabled,
    required String staffName,
    String? password,
  }) async {
    final response = await ApiService.put('/settings/staff', {
      'user_id': userId,
      'enabled': enabled,
      'staff_name': staffName,
      if (password != null && password.isNotEmpty) 'password': password,
    });

    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to update staff settings');
    }

    final current = await getCurrentUser();
    if (current != null) {
      final updated = User(
        id: current.id,
        email: current.email,
        passwordHash: current.passwordHash,
        businessName: current.businessName,
        businessAddress: current.businessAddress,
        phoneNumber: current.phoneNumber,
        contactPerson: current.contactPerson,
        industry: current.industry,
        country: current.country,
        currency: current.currency,
        trialStart: current.trialStart,
        trialEnd: current.trialEnd,
        subscriptionStatus: current.subscriptionStatus,
        subscriptionStart: current.subscriptionStart,
        subscriptionEnd: current.subscriptionEnd,
        onboardingComplete: current.onboardingComplete,
        logoBase64: current.logoBase64,
        salesEntryEnabled: enabled,
        salesEntryPasswordHash: current.salesEntryPasswordHash,
        salesEntryStaffName: staffName,
      );
      await _saveCurrentUser(updated, isStaffLogin: false);
    }
  }
}
