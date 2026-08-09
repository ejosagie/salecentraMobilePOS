class InventoryItem {
  final String id;
  final String userId;
  final String item;
  int stock;
  final double costPrice;
  final double sellingPrice;
  final String? expiryDate;

  InventoryItem({
    required this.id,
    required this.userId,
    required this.item,
    required this.stock,
    required this.costPrice,
    required this.sellingPrice,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'item': item,
      'stock': stock,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'expiry_date': expiryDate,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      userId: map['user_id'],
      item: map['item'],
      stock: map['stock'],
      costPrice: map['cost_price'].toDouble(),
      sellingPrice: map['selling_price'].toDouble(),
      expiryDate: map['expiry_date'] != null ? map['expiry_date'].toString() : null,
    );
  }

  double get profitMargin {
    if (costPrice <= 0) return 0;
    return ((sellingPrice - costPrice) / costPrice) * 100;
  }

  InventoryItem copyWith({
    String? id,
    String? userId,
    String? item,
    int? stock,
    double? costPrice,
    double? sellingPrice,
    String? expiryDate,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      item: item ?? this.item,
      stock: stock ?? this.stock,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }
}
