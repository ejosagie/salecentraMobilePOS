import '../models/inventory.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/invoice.dart';
import 'api_service.dart';

class RemoteDatabaseService {
  
  // ==================== INVENTORY ====================
  
  Future<List<InventoryItem>> getInventory(String userId) async {
    final response = await ApiService.get('/inventory', params: {'user_id': userId});
    if (response['success']) {
      return (response['inventory'] as List)
          .map((item) => InventoryItem.fromMap(item))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch inventory');
  }

  Future<void> addInventoryItem(InventoryItem item) async {
    final response = await ApiService.post('/inventory', {
      'user_id': item.userId,
      'item': item.item,
      'stock': item.stock,
      'cost_price': item.costPrice,
      'selling_price': item.sellingPrice,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to add item');
    }
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final response = await ApiService.put('/inventory/${item.id}', {
      'item': item.item,
      'stock': item.stock,
      'cost_price': item.costPrice,
      'selling_price': item.sellingPrice,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to update item');
    }
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final response = await ApiService.delete('/inventory/$itemId');
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to delete item');
    }
  }

  Future<void> updateStock(String itemId, int newStock) async {
    final response = await ApiService.post('/inventory/stock', {
      'item_id': itemId,
      'new_stock': newStock,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to update stock');
    }
  }

  // ==================== SALES ====================
  
  Future<List<Sale>> getSales(String userId, {DateTime? startDate, DateTime? endDate}) async {
    final params = {'user_id': userId};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();
    
    final response = await ApiService.get('/sales', params: params);
    if (response['success']) {
      return (response['sales'] as List)
          .map((sale) => Sale.fromMap(sale))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch sales');
  }

  Future<double> getTotalSales(String userId, {DateTime? startDate, DateTime? endDate}) async {
    final params = {'user_id': userId};
    if (startDate != null) params['start_date'] = startDate.toIso8601String();
    if (endDate != null) params['end_date'] = endDate.toIso8601String();
    
    final response = await ApiService.get('/sales/total', params: params);
    if (response['success']) {
      return (response['total'] as num).toDouble();
    }
    throw Exception(response['error'] ?? 'Failed to fetch total sales');
  }

  Future<void> recordSale(Sale sale) async {
    final response = await ApiService.post('/sales', {
      'user_id': sale.userId,
      'date': sale.date.toIso8601String(),
      'item': sale.item,
      'quantity': sale.quantity,
      'price': sale.price,
      'entered_by_staff_name': sale.enteredByStaffName,
      'entry_mode': sale.entryMode,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to record sale');
    }
  }

  // ==================== CUSTOMERS ====================
  
  Future<List<Customer>> getCustomers(String userId) async {
    final response = await ApiService.get('/customers', params: {'user_id': userId});
    if (response['success']) {
      return (response['customers'] as List)
          .map((customer) => Customer.fromMap(customer))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch customers');
  }

  Future<void> addCustomer(Customer customer) async {
    final response = await ApiService.post('/customers', {
      'user_id': customer.userId,
      'name': customer.name,
      'email': customer.email,
      'phone': customer.phone,
      'address': customer.address,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to add customer');
    }
  }

  // ==================== EXPENSES ====================
  
  Future<List<Expense>> getExpenses(String userId) async {
    final response = await ApiService.get('/expenses', params: {'user_id': userId});
    if (response['success']) {
      return (response['expenses'] as List)
          .map((expense) => Expense.fromMap(expense))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch expenses');
  }

  Future<void> addExpense(Expense expense) async {
    final response = await ApiService.post('/expenses', {
      'user_id': expense.userId,
      'category': expense.category,
      'amount': expense.amount,
      'description': expense.description,
      'date': expense.date.toIso8601String(),
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to add expense');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final response = await ApiService.delete('/expenses/$expenseId');
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to delete expense');
    }
  }

  // ==================== DEBTS ====================
  
  Future<List<Debt>> getDebts(String userId, {String? type}) async {
    final params = {'user_id': userId};
    if (type != null) params['type'] = type;
    
    final response = await ApiService.get('/debts', params: params);
    if (response['success']) {
      return (response['debts'] as List)
          .map((debt) => Debt.fromMap(debt))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch debts');
  }

  Future<void> addDebt(Debt debt) async {
    final response = await ApiService.post('/debts', {
      'user_id': debt.userId,
      'customer_id': debt.customerId,
      'type': debt.type,
      'amount': debt.amount,
      'description': debt.description,
      'due_date': debt.dueDate?.toIso8601String(),
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to add debt');
    }
  }

  Future<void> recordDebtPayment(String debtId, double amount, {String? note}) async {
    final response = await ApiService.post('/debts/payment', {
      'debt_id': debtId,
      'amount': amount,
      'note': note,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to record payment');
    }
  }

  Future<Map<String, double>> getDebtSummary(String userId) async {
    final response = await ApiService.get('/debts/summary', params: {'user_id': userId});
    if (response['success']) {
      return {
        'owed_to_me': (response['owed_to_me'] as num).toDouble(),
        'i_owe': (response['i_owe'] as num).toDouble(),
      };
    }
    throw Exception(response['error'] ?? 'Failed to fetch debt summary');
  }

  // ==================== INVOICES ====================
  
  Future<List<Invoice>> getInvoices(String userId, {String? status}) async {
    final params = {'user_id': userId};
    if (status != null) params['status'] = status;
    
    final response = await ApiService.get('/invoices', params: params);
    if (response['success']) {
      return (response['invoices'] as List)
          .map((invoice) => Invoice.fromMap(invoice))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch invoices');
  }

  Future<void> addInvoice(Invoice invoice) async {
    final response = await ApiService.post('/invoices', {
      'user_id': invoice.userId,
      'customer_id': invoice.customerId,
      'date': invoice.date.toIso8601String(),
      'due_date': invoice.dueDate?.toIso8601String(),
      'total': invoice.total,
      'status': invoice.status,
      'notes': invoice.notes,
      'items': invoice.items.map((item) => item.toMap()).toList(),
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to add invoice');
    }
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final response = await ApiService.put('/invoices/${invoice.id}', {
      'customer_id': invoice.customerId,
      'due_date': invoice.dueDate?.toIso8601String(),
      'total': invoice.total,
      'status': invoice.status,
      'notes': invoice.notes,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to update invoice');
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final response = await ApiService.delete('/invoices/$invoiceId');
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to delete invoice');
    }
  }

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) async {
    final response = await ApiService.get('/invoices/$invoiceId/items');
    if (response['success']) {
      return (response['items'] as List)
          .map((item) => InvoiceItem.fromMap(item))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch invoice items');
  }
}
