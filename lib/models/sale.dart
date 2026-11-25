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
  final String? refundStatus;
  final double refundedAmount;

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
    this.refundStatus,
    this.refundedAmount = 0.0,
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
      'refund_status': refundStatus,
      'refunded_amount': refundedAmount,
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
      refundStatus: map['refund_status'],
      refundedAmount: (map['refunded_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isRefunded => refundStatus != null;
  bool get isFullyRefunded => refundStatus == 'fully_refunded';
  bool get isPartiallyRefunded => refundStatus == 'partially_refunded';
  double get netTotal => total - refundedAmount;
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

  Map<String, dynamic> toJson() => {
        'inventory_item': inventoryItem.toMap(),
        'quantity': quantity,
        'discount': discount,
        'custom_price': _customPrice,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final item = CartItem(
      inventoryItem: InventoryItem.fromMap(json['inventory_item'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
    );
    final customPrice = json['custom_price'];
    if (customPrice != null) item.unitPrice = (customPrice as num).toDouble();
    return item;
  }
}

class HeldCart {
  final String id;
  final List<CartItem> items;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final DateTime heldAt;
  final String label;

  HeldCart({
    required this.id,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.heldAt,
    this.label = '',
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  Map<String, dynamic> toJson() => {
        'id': id,
        'items': items.map((i) => i.toJson()).toList(),
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'held_at': heldAt.toIso8601String(),
        'label': label,
      };

  factory HeldCart.fromJson(Map<String, dynamic> json) => HeldCart(
        id: json['id'] as String,
        items: (json['items'] as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
        customerAddress: json['customer_address'] as String?,
        heldAt: DateTime.parse(json['held_at'] as String),
        label: json['label'] as String? ?? '',
      );
}
