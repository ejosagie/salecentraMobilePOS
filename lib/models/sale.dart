import 'inventory.dart';

class Sale {
  final String id;
  final String userId;
  final DateTime date;
  final String item;
  final int quantity;
  final double price;
  final double discount;
  final double total;
  final double costPrice;
  final String? enteredByStaffName;
  final String? entryMode;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;

  Sale({
    required this.id,
    required this.userId,
    required this.date,
    required this.item,
    required this.quantity,
    required this.price,
    this.discount = 0.0,
    required this.total,
    this.costPrice = 0.0,
    this.enteredByStaffName,
    this.entryMode = 'owner',
    this.customerName,
    this.customerPhone,
    this.customerAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'item': item,
      'quantity': quantity,
      'price': price,
      'discount': discount,
      'total': total,
      'cost_price': costPrice,
      'entered_by_staff_name': enteredByStaffName,
      'entered_by_staff_name_normalized': enteredByStaffName?.toLowerCase().trim(),
      'entry_mode': entryMode,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_address': customerAddress,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']),
      item: map['item'],
      quantity: map['quantity'],
      price: map['price'].toDouble(),
      discount: (map['discount'] ?? 0.0).toDouble(),
      total: map['total'].toDouble(),
      costPrice: (map['cost_price'] ?? 0.0).toDouble(),
      enteredByStaffName: map['entered_by_staff_name'],
      entryMode: map['entry_mode'] ?? 'owner',
      customerName: map['customer_name'],
      customerPhone: map['customer_phone'],
      customerAddress: map['customer_address'],
    );
  }
}

class CartItem {
  final InventoryItem inventoryItem;
  int quantity;
  double discount;
  double? _customPrice;

  CartItem({
    required this.inventoryItem,
    this.quantity = 1,
    this.discount = 0,
  });

  double get unitPrice => _customPrice ?? inventoryItem.sellingPrice;
  set unitPrice(double value) => _customPrice = value;
  bool get hasCustomPrice => _customPrice != null;
  void resetPrice() => _customPrice = null;
  double get totalPrice => (unitPrice * quantity) - discount;
  String get itemName => inventoryItem.item;
}
