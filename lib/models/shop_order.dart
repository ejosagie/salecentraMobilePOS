import 'dart:convert';

class ShopOrder {
  final String id;
  final String shopSlug;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final List<ShopOrderItem> items;
  final double totalAmount;
  final String currency;
  final String paymentMethod;
  final String status;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  ShopOrder({
    required this.id,
    required this.shopSlug,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    required this.items,
    required this.totalAmount,
    required this.currency,
    required this.paymentMethod,
    this.status = 'pending',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ShopOrder.fromMap(Map<String, dynamic> map) {
    List<ShopOrderItem> parseItems(dynamic itemsData) {
      if (itemsData == null) return [];
      if (itemsData is String) {
        try {
          final list = jsonDecode(itemsData) as List;
          return list.map((e) => ShopOrderItem.fromMap(e as Map<String, dynamic>)).toList();
        } catch (_) {
          return [];
        }
      }
      if (itemsData is List) {
        return itemsData.map((e) => ShopOrderItem.fromMap(e as Map<String, dynamic>)).toList();
      }
      return [];
    }

    return ShopOrder(
      id: map['id'] as String,
      shopSlug: map['shop_slug'] as String? ?? '',
      customerName: map['customer_name'] as String? ?? '',
      customerPhone: map['customer_phone'] as String? ?? '',
      customerEmail: map['customer_email'] as String?,
      customerAddress: map['customer_address'] as String?,
      items: parseItems(map['items']),
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? '',
      paymentMethod: map['payment_method'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }
}

class ShopOrderItem {
  final String name;
  final double price;
  final int quantity;

  ShopOrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory ShopOrderItem.fromMap(Map<String, dynamic> map) {
    return ShopOrderItem(
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as int?) ?? 1,
    );
  }
}
