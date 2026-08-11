class Customer {
  final String id;
  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime createdAt;
  double totalPurchases;
  int purchaseCount;

  Customer({
    required this.id,
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    this.address,
    DateTime? createdAt,
    this.totalPurchases = 0,
    this.purchaseCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Customer(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      address: map['address']?.toString(),
      createdAt: parseCreatedAt(map['created_at']),
      totalPurchases: (map['total_purchases'] as num?)?.toDouble() ?? 0,
      purchaseCount: (map['purchase_count'] as num?)?.toInt() ?? 0,
    );
  }
}
