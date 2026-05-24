class Debt {
  final String id;
  final String userId;
  final String? customerId;
  final String type; // 'receivable' or 'payable'
  final double amount;
  double balance;
  final String? description;
  final DateTime date;
  final DateTime? dueDate;
  String status; // 'unpaid', 'paid', 'partial'

  Debt({
    required this.id,
    required this.userId,
    this.customerId,
    required this.type,
    required this.amount,
    required this.balance,
    this.description,
    DateTime? date,
    this.dueDate,
    this.status = 'unpaid',
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'customer_id': customerId,
      'type': type,
      'amount': amount,
      'balance': balance,
      'description': description,
      'date': date.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'status': status,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      userId: map['user_id'],
      customerId: map['customer_id'],
      type: map['type'],
      amount: map['amount'].toDouble(),
      balance: map['balance'].toDouble(),
      description: map['description'],
      date: DateTime.parse(map['date']),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      status: map['status'] ?? 'unpaid',
    );
  }

  bool get isOverdue {
    if (dueDate == null || status == 'paid') return false;
    return DateTime.now().isAfter(dueDate!);
  }
}

class DebtPayment {
  final String id;
  final String debtId;
  final double amount;
  final DateTime date;
  final String? note;

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    DateTime? date,
    this.note,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'],
      debtId: map['debt_id'],
      amount: map['amount'].toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }
}
