class User {
  final String id;
  final String email;
  final String passwordHash;
  final String businessName;
  final String businessAddress;
  final String phoneNumber;
  final String contactPerson;
  final String industry;
  final String country;
  final String currency;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final String subscriptionStatus;
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;
  final bool onboardingComplete;
  final String? logoBase64;
  final bool salesEntryEnabled;
  final String? salesEntryPasswordHash;
  final String? salesEntryStaffName;

  User({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.businessName,
    required this.businessAddress,
    required this.phoneNumber,
    required this.contactPerson,
    required this.industry,
    required this.country,
    this.currency = 'NGN',
    this.trialStart,
    this.trialEnd,
    this.subscriptionStatus = 'trial',
    this.subscriptionStart,
    this.subscriptionEnd,
    this.onboardingComplete = false,
    this.logoBase64,
    this.salesEntryEnabled = false,
    this.salesEntryPasswordHash,
    this.salesEntryStaffName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password_hash': passwordHash,
      'business_name': businessName,
      'business_address': businessAddress,
      'phone_number': phoneNumber,
      'contact_person': contactPerson,
      'industry': industry,
      'country': country,
      'currency': currency,
      'trial_start': trialStart?.toIso8601String(),
      'trial_end': trialEnd?.toIso8601String(),
      'subscription_status': subscriptionStatus,
      'subscription_start': subscriptionStart?.toIso8601String(),
      'subscription_end': subscriptionEnd?.toIso8601String(),
      'onboarding_complete': onboardingComplete ? 1 : 0,
      'logo_base64': logoBase64,
      'sales_entry_enabled': salesEntryEnabled ? 1 : 0,
      'sales_entry_password_hash': salesEntryPasswordHash,
      'sales_entry_staff_name': salesEntryStaffName,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    return User(
      id: map['id'],
      email: map['email'],
      passwordHash: map['password_hash'],
      businessName: map['business_name'],
      businessAddress: map['business_address'],
      phoneNumber: map['phone_number'],
      contactPerson: map['contact_person'],
      industry: map['industry'],
      country: map['country'],
      currency: map['currency'] ?? 'NGN',
      trialStart: map['trial_start'] != null ? DateTime.tryParse(map['trial_start']) : null,
      trialEnd: map['trial_end'] != null ? DateTime.tryParse(map['trial_end']) : null,
      subscriptionStatus: map['subscription_status'] ?? 'trial',
      subscriptionStart: map['subscription_start'] != null ? DateTime.tryParse(map['subscription_start']) : null,
      subscriptionEnd: map['subscription_end'] != null ? DateTime.tryParse(map['subscription_end']) : null,
      onboardingComplete: parseBool(map['onboarding_complete']),
      logoBase64: map['logo_base64'],
      salesEntryEnabled: parseBool(map['sales_entry_enabled']),
      salesEntryPasswordHash: map['sales_entry_password_hash'],
      salesEntryStaffName: map['sales_entry_staff_name'],
    );
  }

  bool get isTrialActive {
    if (subscriptionStatus == 'active') return true;
    if (trialEnd == null) return false;
    return DateTime.now().isBefore(trialEnd!);
  }

  /// Computes the real, current account status instead of trusting the
  /// raw stored value. Mirrors the web app's get_user_status logic.
  /// Returns one of: 'active', 'trial', 'expired', 'suspended'.
  String get effectiveStatus {
    final status = subscriptionStatus.toLowerCase();

    if (status == 'suspended') return 'suspended';

    if (status == 'active') {
      if (subscriptionEnd != null && DateTime.now().isAfter(subscriptionEnd!)) {
        return 'expired';
      }
      return 'active';
    }

    if (status == 'expired') return 'expired';

    // Trial (default): expired if no end date or past the end date.
    if (trialEnd == null) return 'expired';
    if (DateTime.now().isAfter(trialEnd!)) return 'expired';
    return 'trial';
  }

  /// True when the account should be blocked from using the app.
  bool get isAccessBlocked {
    final status = effectiveStatus;
    return status == 'expired' || status == 'suspended';
  }

  User copyWith({
    String? id,
    String? email,
    String? passwordHash,
    String? businessName,
    String? businessAddress,
    String? phoneNumber,
    String? contactPerson,
    String? industry,
    String? country,
    String? currency,
    DateTime? trialStart,
    DateTime? trialEnd,
    String? subscriptionStatus,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    bool? onboardingComplete,
    String? logoBase64,
    bool? salesEntryEnabled,
    String? salesEntryPasswordHash,
    String? salesEntryStaffName,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactPerson: contactPerson ?? this.contactPerson,
      industry: industry ?? this.industry,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      trialStart: trialStart ?? this.trialStart,
      trialEnd: trialEnd ?? this.trialEnd,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      logoBase64: logoBase64 ?? this.logoBase64,
      salesEntryEnabled: salesEntryEnabled ?? this.salesEntryEnabled,
      salesEntryPasswordHash: salesEntryPasswordHash ?? this.salesEntryPasswordHash,
      salesEntryStaffName: salesEntryStaffName ?? this.salesEntryStaffName,
    );
  }

  String get currencySymbol {
    const symbols = {
      'NGN': '₦',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'KES': 'KSh',
      'GHS': '₵',
      'ZAR': 'R',
      'XOF': 'CFA',
      'XAF': 'FCFA',
      'UGX': 'USh',
      'TZS': 'TSh',
      'ETB': 'Br',
      'DZD': 'دج',
      'MAD': 'DH',
      'EGP': '£E',
      'AED': 'د.إ',
      'SAR': '﷼',
      'INR': '₹',
      'PKR': '₨',
      'CAD': 'C\$',
      'AUD': 'A\$',
      'JPY': '¥',
      'CNY': '¥',
      'BRL': 'R\$',
      'MXN': 'Mex\$',
    };
    return symbols[currency] ?? currency;
  }
}
