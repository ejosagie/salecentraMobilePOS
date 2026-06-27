class StaffAccount {
  final String id;
  final String staffName;
  final String? createdAt;

  StaffAccount({
    required this.id,
    required this.staffName,
    this.createdAt,
  });

  factory StaffAccount.fromMap(Map<String, dynamic> map) {
    return StaffAccount(
      id: map['id'] as String,
      staffName: map['staff_name'] as String? ?? '',
      createdAt: map['created_at'] as String?,
    );
  }
}

class StaffSubscription {
  final String id;
  final String tier;
  final int additionalStaffCount;
  final String status;
  final String startDate;
  final String endDate;

  StaffSubscription({
    required this.id,
    required this.tier,
    required this.additionalStaffCount,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  factory StaffSubscription.fromMap(Map<String, dynamic> map) {
    return StaffSubscription(
      id: map['id'] as String? ?? '',
      tier: map['tier'] as String? ?? '',
      additionalStaffCount: (map['additional_staff_count'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? '',
      startDate: map['start_date'] as String? ?? '',
      endDate: map['end_date'] as String? ?? '',
    );
  }
}

class StaffSubscriptionStatus {
  final int currentCount;
  final int staffLimit;
  final bool hasActiveSubscription;
  final StaffSubscription? subscription;

  StaffSubscriptionStatus({
    required this.currentCount,
    required this.staffLimit,
    required this.hasActiveSubscription,
    this.subscription,
  });

  bool get canAddMore => currentCount < staffLimit;

  factory StaffSubscriptionStatus.fromMap(Map<String, dynamic> map) {
    final subData = map['subscription'] as Map<String, dynamic>?;
    return StaffSubscriptionStatus(
      currentCount: (map['current_count'] as num?)?.toInt() ?? 0,
      staffLimit: (map['staff_limit'] as num?)?.toInt() ?? 1,
      hasActiveSubscription: map['has_active_subscription'] == true,
      subscription: subData != null ? StaffSubscription.fromMap(subData) : null,
    );
  }
}
