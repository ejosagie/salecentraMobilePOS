import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user.dart';
import '../models/inventory.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/expense.dart';
import '../models/debt.dart';
import '../models/invoice.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'salecentra.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE,
        password_hash TEXT,
        business_name TEXT,
        business_address TEXT,
        phone_number TEXT,
        contact_person TEXT,
        industry TEXT,
        country TEXT,
        currency TEXT DEFAULT 'NGN',
        trial_start TEXT,
        trial_end TEXT,
        subscription_status TEXT DEFAULT 'trial',
        subscription_start TEXT,
        subscription_end TEXT,
        onboarding_complete INTEGER DEFAULT 0,
        logo_base64 TEXT,
        sales_entry_enabled INTEGER DEFAULT 0,
        sales_entry_password_hash TEXT,
        sales_entry_staff_name TEXT,
        sales_entry_staff_name_normalized TEXT
      )
    ''');

    // Inventory table
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        item TEXT,
        stock INTEGER,
        cost_price REAL,
        selling_price REAL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        date TEXT,
        item TEXT,
        quantity INTEGER,
        price REAL,
        total REAL,
        entered_by_staff_name TEXT,
        entered_by_staff_name_normalized TEXT,
        entry_mode TEXT DEFAULT 'owner',
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT,
        email TEXT,
        phone TEXT,
        address TEXT,
        created_at TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        category TEXT,
        amount REAL,
        description TEXT,
        date TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Debts table
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        customer_id TEXT,
        type TEXT,
        amount REAL,
        balance REAL,
        description TEXT,
        date TEXT,
        due_date TEXT,
        status TEXT DEFAULT 'unpaid',
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // Debt payments table
    await db.execute('''
      CREATE TABLE debt_payments (
        id TEXT PRIMARY KEY,
        debt_id TEXT,
        amount REAL,
        date TEXT,
        note TEXT,
        FOREIGN KEY (debt_id) REFERENCES debts(id)
      )
    ''');

    // Invoices table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        customer_id TEXT,
        date TEXT,
        due_date TEXT,
        total REAL,
        status TEXT DEFAULT 'unpaid',
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // Invoice items table
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT,
        description TEXT,
        quantity INTEGER,
        unit_price REAL,
        total REAL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id)
      )
    ''');

    // Receipts table
    await db.execute('''
      CREATE TABLE receipts (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        sale_ids TEXT,
        customer_name TEXT,
        total_amount REAL,
        receipt_text TEXT,
        date TEXT,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Offline sales table (queued for sync)
    await db.execute('''
      CREATE TABLE offline_sales (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        date TEXT,
        item TEXT,
        quantity INTEGER,
        price REAL,
        discount REAL,
        total REAL,
        cost_price REAL,
        entered_by_staff_name TEXT,
        entry_mode TEXT DEFAULT 'owner',
        customer_name TEXT,
        customer_phone TEXT,
        customer_address TEXT,
        inventory_item_id TEXT,
        new_stock INTEGER,
        synced INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    // Cached inventory table (for offline viewing)
    await db.execute('''
      CREATE TABLE cached_inventory (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        item TEXT,
        stock INTEGER,
        cost_price REAL,
        selling_price REAL,
        expiry_date TEXT,
        cached_at TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS offline_sales (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          date TEXT,
          item TEXT,
          quantity INTEGER,
          price REAL,
          discount REAL,
          total REAL,
          cost_price REAL,
          entered_by_staff_name TEXT,
          entry_mode TEXT DEFAULT 'owner',
          customer_name TEXT,
          customer_phone TEXT,
          customer_address TEXT,
          inventory_item_id TEXT,
          new_stock INTEGER,
          synced INTEGER DEFAULT 0,
          created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_inventory (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          item TEXT,
          stock INTEGER,
          cost_price REAL,
          selling_price REAL,
          expiry_date TEXT,
          cached_at TEXT
        )
      ''');
    }
  }

  // User operations
  Future<String> createUser(User user) async {
    final db = await database;
    await db.insert('users', user.toMap());
    return user.id;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // Inventory operations
  Future<String> addInventoryItem(InventoryItem item) async {
    final db = await database;
    await db.insert('inventory', item.toMap());
    return item.id;
  }

  Future<List<InventoryItem>> getInventory(String userId) async {
    final db = await database;
    final maps = await db.query(
      'inventory',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return maps.map((m) => InventoryItem.fromMap(m)).toList();
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final db = await database;
    await db.update(
      'inventory',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteInventoryItem(String id) async {
    final db = await database;
    await db.delete(
      'inventory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateStock(String itemId, int newStock) async {
    final db = await database;
    await db.update(
      'inventory',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  // Sales operations
  Future<String> recordSale(Sale sale) async {
    final db = await database;
    await db.insert('sales', sale.toMap());
    return sale.id;
  }

  Future<List<Sale>> getSales(String userId, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final maps = await db.query(
      'sales',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<double> getTotalSales(String userId, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (startDate != null) {
      whereClause += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) as total FROM sales WHERE $whereClause',
      whereArgs,
    );
    return result.first['total'] as double;
  }

  // Customer operations
  Future<String> addCustomer(Customer customer) async {
    final db = await database;
    await db.insert('customers', customer.toMap());
    return customer.id;
  }

  Future<List<Customer>> getCustomers(String userId) async {
    final db = await database;
    final maps = await db.query(
      'customers',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<List<Customer>> searchCustomers(String userId, String query) async {
    final db = await database;
    final maps = await db.query(
      'customers',
      where: 'user_id = ? AND (name LIKE ? OR phone LIKE ? OR email LIKE ?)',
      whereArgs: [userId, '%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<void> deleteCustomer(String id) async {
    final db = await database;
    await db.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Expense operations
  Future<String> addExpense(Expense expense) async {
    final db = await database;
    await db.insert('expenses', expense.toMap());
    return expense.id;
  }

  Future<List<Expense>> getExpenses(String userId) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  Future<Map<String, double>> getExpenseSummary(String userId) async {
    final db = await database;
    final maps = await db.rawQuery(
      'SELECT category, SUM(amount) as total FROM expenses WHERE user_id = ? GROUP BY category ORDER BY total DESC',
      [userId],
    );
    return {for (var m in maps) m['category'] as String: (m['total'] as num).toDouble()};
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Debt operations
  Future<String> addDebt(Debt debt) async {
    final db = await database;
    await db.insert('debts', debt.toMap());
    return debt.id;
  }

  Future<List<Debt>> getDebts(String userId, {String? type}) async {
    final db = await database;
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [userId];

    if (type != null) {
      whereClause += ' AND type = ?';
      whereArgs.add(type);
    }

    final maps = await db.query(
      'debts',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  Future<void> recordDebtPayment(DebtPayment payment, String debtId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('debt_payments', payment.toMap());
      
      final debt = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
      );
      
      if (debt.isNotEmpty) {
        final currentBalance = debt.first['balance'] as double;
        final newBalance = currentBalance - payment.amount;
        final newStatus = newBalance <= 0 ? 'paid' : 'unpaid';
        
        await txn.update(
          'debts',
          {'balance': newBalance, 'status': newStatus},
          where: 'id = ?',
          whereArgs: [debtId],
        );
      }
    });
  }

  Future<Map<String, double>> getDebtSummary(String userId) async {
    final db = await database;
    final receivableResult = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) as total FROM debts WHERE user_id = ? AND type = ? AND status = ?',
      [userId, 'receivable', 'unpaid'],
    );
    final payableResult = await db.rawQuery(
      'SELECT COALESCE(SUM(balance), 0) as total FROM debts WHERE user_id = ? AND type = ? AND status = ?',
      [userId, 'payable', 'unpaid'],
    );
    
    return {
      'owed_to_me': receivableResult.first['total'] as double,
      'i_owe': payableResult.first['total'] as double,
    };
  }

  // Invoice operations
  Future<String> createInvoice(Invoice invoice) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('invoices', invoice.toMap());
      for (var item in invoice.items) {
        await txn.insert('invoice_items', item.toMap());
      }
    });
    return invoice.id;
  }

  Future<List<Invoice>> getInvoices(String userId) async {
    final db = await database;
    final maps = await db.query(
      'invoices',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    final db = await database;
    await db.update(
      'invoices',
      {'status': status},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  // ==================== OFFLINE SALES ====================

  Future<void> saveOfflineSale(Map<String, dynamic> saleData) async {
    final db = await database;
    await db.insert('offline_sales', {
      ...saleData,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedOfflineSales() async {
    final db = await database;
    return await db.query('offline_sales', where: 'synced = 0');
  }

  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM offline_sales WHERE synced = 0');
    return result.first['count'] as int;
  }

  Future<void> markOfflineSaleSynced(String id) async {
    final db = await database;
    await db.update('offline_sales', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSyncedOfflineSales() async {
    final db = await database;
    await db.delete('offline_sales', where: 'synced = 1');
  }

  // ==================== CACHED INVENTORY ====================

  Future<void> cacheInventory(List<InventoryItem> items, String userId) async {
    final db = await database;
    await db.delete('cached_inventory', where: 'user_id = ?', whereArgs: [userId]);
    final now = DateTime.now().toIso8601String();
    for (final item in items) {
      await db.insert('cached_inventory', {
        'id': item.id,
        'user_id': userId,
        'item': item.item,
        'stock': item.stock,
        'cost_price': item.costPrice,
        'selling_price': item.sellingPrice,
        'expiry_date': item.expiryDate,
        'cached_at': now,
      });
    }
  }

  Future<List<InventoryItem>> getCachedInventory(String userId) async {
    final db = await database;
    final maps = await db.query('cached_inventory', where: 'user_id = ?', whereArgs: [userId]);
    return maps.map((m) => InventoryItem(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      item: m['item'] as String,
      stock: m['stock'] as int,
      costPrice: m['cost_price'] as double,
      sellingPrice: m['selling_price'] as double,
      expiryDate: m['expiry_date'] as String?,
    )).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
