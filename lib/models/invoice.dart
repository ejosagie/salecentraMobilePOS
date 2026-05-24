class Invoice {
  final String id;
  final String userId;
  final String? customerId;
  final DateTime date;
  final DateTime? dueDate;
  final double total;
  String status; // 'unpaid', 'paid', 'overdue', 'cancelled'
  final String? notes;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.userId,
    this.customerId,
    required this.date,
    this.dueDate,
    required this.total,
    this.status = 'unpaid',
    this.notes,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'customer_id': customerId,
      'date': date.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'total': total,
      'status': status,
      'notes': notes,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Invoice(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      customerId: map['customer_id']?.toString(),
      date: parseDate(map['date'], DateTime.now()),
      dueDate: parseNullableDate(map['due_date']),
      total: parseDouble(map['total']),
      status: (map['status']?.toString().isNotEmpty ?? false)
          ? map['status'].toString()
          : 'unpaid',
      notes: map['notes'],
    );
  }

  bool get isOverdue {
    if (dueDate == null || status == 'paid') return false;
    return DateTime.now().isAfter(dueDate!);
  }
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return InvoiceItem(
      id: map['id']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      quantity: parseInt(map['quantity']),
      unitPrice: parseDouble(map['unit_price']),
      total: parseDouble(map['total']),
    );
  }
}
