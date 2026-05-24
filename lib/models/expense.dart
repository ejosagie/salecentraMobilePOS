class Expense {
  final String id;
  final String userId;
  final String category;
  final double amount;
  final String? description;
  final DateTime date;

  Expense({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    this.description,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      userId: map['user_id'],
      category: map['category'],
      amount: map['amount'].toDouble(),
      description: map['description'],
      date: DateTime.parse(map['date']),
    );
  }
}

class ExpenseCategory {
  static const List<String> defaultCategories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Supplies',
    'Marketing',
    'Transportation',
    'Maintenance',
    'Insurance',
    'Taxes',
    'Other',
  ];
}
