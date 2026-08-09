import 'dart:io';
import '../models/inventory.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/invoice.dart';
import '../models/notification.dart';
import '../models/shop_settings.dart';
import '../models/shop_product.dart';
import '../models/shop_order.dart';
import '../models/announcement.dart';
import '../models/premium_staff.dart';
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
      'expiry_date': item.expiryDate,
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
      'expiry_date': item.expiryDate,
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
      'discount': sale.discount,
      'cost_price': sale.costPrice,
      'entered_by_staff_name': sale.enteredByStaffName,
      'entry_mode': sale.entryMode,
      'customer_name': sale.customerName,
      'customer_phone': sale.customerPhone,
      'customer_address': sale.customerAddress,
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

  Future<List<Customer>> searchCustomers(String userId, String term) async {
    final response = await ApiService.get('/customers/search', params: {
      'user_id': userId,
      'term': term,
    });
    if (response['success']) {
      return (response['customers'] as List)
          .map((customer) => Customer.fromMap(customer))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to search customers');
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

  Future<void> updateCustomer(Customer customer) async {
    final response = await ApiService.put('/customers/${customer.id}', {
      'name': customer.name,
      'email': customer.email,
      'phone': customer.phone,
      'address': customer.address,
    });
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to update customer');
    }
  }

  // ==================== NOTIFICATIONS ====================

  Future<List<AppNotification>> getNotifications(String userId) async {
    final response = await ApiService.get('/notifications', params: {'user_id': userId});
    if (response['success']) {
      return (response['notifications'] as List)
          .map((n) => AppNotification.fromMap(n))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch notifications');
  }

  Future<void> markNotificationRead(String notificationId) async {
    final response = await ApiService.put('/notifications/$notificationId/read', {});
    if (!response['success']) {
      throw Exception(response['error'] ?? 'Failed to mark notification as read');
    }
  }

  // ==================== FORECAST ====================

  Future<Map<String, dynamic>> getForecast(String userId, {int days = 30}) async {
    final response = await ApiService.get('/forecast', params: {'user_id': userId, 'days': days.toString()});
    if (response['success'] || response['error'] == 'INSUFFICIENT_DATA') {
      return response;
    }
    throw Exception(response['error'] ?? 'Failed to fetch forecast');
  }

  Future<Map<String, dynamic>> getPricingAnalysis(String userId) async {
    final response = await ApiService.get('/pricing-analysis', params: {'user_id': userId});
    if (response['success'] || response['error'] == 'INSUFFICIENT_DATA') {
      return response;
    }
    throw Exception(response['error'] ?? 'Failed to fetch pricing analysis');
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

  Future<List<DebtPayment>> getDebtPayments(String debtId) async {
    final response = await ApiService.get('/debts/payments', params: {'debt_id': debtId});
    if (response['success']) {
      return (response['payments'] as List)
          .map((p) => DebtPayment.fromMap(p))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch payment history');
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

  // ==================== SHOP ====================

  Future<ShopSettings> getShopSettings(String userId) async {
    final response = await ApiService.get('/storefront/admin/shop', params: {'user_id': userId});
    if (response['success'] == true) {
      return ShopSettings.fromMap(response);
    }
    throw Exception(response['error'] ?? 'Failed to fetch shop settings');
  }

  Future<void> saveShopSettings(String userId, ShopSettings settings) async {
    final data = settings.toMap();
    data['user_id'] = userId;
    final response = await ApiService.post('/storefront/admin/shop', data);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to save shop settings');
    }
  }

  Future<List<ShopProduct>> getShopProducts(String userId) async {
    final response = await ApiService.get('/storefront/admin/products', params: {'user_id': userId});
    if (response['success'] == true) {
      return (response['products'] as List)
          .map((p) => ShopProduct.fromMap(p as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch shop products');
  }

  Future<void> addShopProduct(String userId, Map<String, dynamic> productData) async {
    productData['user_id'] = userId;
    final response = await ApiService.post('/storefront/admin/products', productData);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to add product');
    }
  }

  Future<void> updateShopProduct(String userId, String productId, Map<String, dynamic> data) async {
    data['user_id'] = userId;
    final response = await ApiService.put('/storefront/admin/products/$productId', data);
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to update product');
    }
  }

  Future<void> deleteShopProduct(String userId, String productId) async {
    final response = await ApiService.delete('/storefront/admin/products/$productId?user_id=$userId');
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to delete product');
    }
  }

  Future<String> uploadShopImage(String userId, String inventoryId, int imageIndex, File imageFile) async {
    final response = await ApiService.uploadFile('/storefront/admin/upload-image', imageFile, {
      'user_id': userId,
      'inventory_id': inventoryId,
      'image_index': imageIndex.toString(),
    });
    if (response['success'] == true) {
      return response['image_url'] as String;
    }
    throw Exception(response['error'] ?? 'Failed to upload image');
  }

  Future<void> deleteShopImage(String userId, String inventoryId, int imageIndex) async {
    final response = await ApiService.delete(
      '/storefront/admin/delete-image?user_id=$userId&inventory_id=$inventoryId&image_index=$imageIndex',
    );
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to delete image');
    }
  }

  Future<List<ShopOrder>> getShopOrders(String userId, {String? status}) async {
    final params = {'user_id': userId};
    if (status != null && status != 'All') {
      params['status'] = status.toLowerCase();
    }
    final response = await ApiService.get('/storefront/admin/orders', params: params);
    if (response['success'] == true) {
      return (response['orders'] as List)
          .map((o) => ShopOrder.fromMap(o as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch shop orders');
  }

  Future<void> updateOrderStatus(String userId, String orderId, String status) async {
    final response = await ApiService.put('/storefront/admin/orders/$orderId/status', {
      'user_id': userId,
      'status': status,
    });
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to update order status');
    }
  }

  // ==================== PREMIUM STAFF ====================

  Future<List<StaffAccount>> getStaffAccounts(String userId) async {
    final response = await ApiService.get('/staff/accounts', params: {'user_id': userId});
    if (response['success'] == true) {
      return (response['accounts'] as List)
          .map((a) => StaffAccount.fromMap(a as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch staff accounts');
  }

  Future<void> createStaffAccount(String userId, String staffName, String password) async {
    final response = await ApiService.post('/staff/accounts', {
      'user_id': userId,
      'staff_name': staffName,
      'password': password,
    });
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to create staff account');
    }
  }

  Future<void> deleteStaffAccount(String userId, String accountId) async {
    final response = await ApiService.delete('/staff/accounts/$accountId?user_id=$userId');
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to delete staff account');
    }
  }

  Future<StaffSubscriptionStatus> getStaffSubscriptionStatus(String userId) async {
    final response = await ApiService.get('/staff/subscription', params: {'user_id': userId});
    if (response['success'] == true) {
      return StaffSubscriptionStatus.fromMap(response);
    }
    throw Exception(response['error'] ?? 'Failed to fetch staff subscription status');
  }

  // ==================== ANNOUNCEMENTS ====================

  Future<List<Announcement>> getAnnouncements(String userId) async {
    final response = await ApiService.get('/announcements', params: {'user_id': userId});
    if (response['success'] == true) {
      return (response['announcements'] as List)
          .map((a) => Announcement.fromMap(a as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response['error'] ?? 'Failed to fetch announcements');
  }

  Future<void> dismissAnnouncement(String userId, int announcementId) async {
    final response = await ApiService.post('/announcements/$announcementId/dismiss', {
      'user_id': userId,
    });
    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to dismiss announcement');
    }
  }
}
