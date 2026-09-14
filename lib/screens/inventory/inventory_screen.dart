import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../models/inventory.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  
  List<InventoryItem> _inventory = [];
  List<InventoryItem> _filteredInventory = [];
  User? _user;
  bool _isLoading = true;
  bool _isStaff = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    final isStaff = await _authService.isStaffLogin();
    if (user == null) return;

    final inventory = await _dbService.getInventory(user.id);

    setState(() {
      _user = user;
      _isStaff = isStaff;
      _inventory = inventory;
      _filteredInventory = inventory;
      _isLoading = false;
    });
  }

  void _filterInventory(String query) {
    setState(() {
      _filteredInventory = _inventory
          .where((item) => item.item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  String get currencySymbol => _user?.currencySymbol ?? '₦';

  Future<void> _showAddItemDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        userId: _user!.id,
        currencySymbol: currencySymbol,
        onItemAdded: _loadData,
      ),
    );
  }

  Future<void> _showEditItemDialog(InventoryItem item) async {
    await showDialog(
      context: context,
      builder: (context) => EditItemDialog(
        item: item,
        currencySymbol: currencySymbol,
        onItemUpdated: _loadData,
      ),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.item}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbService.deleteInventoryItem(item.id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          if (!_isStaff)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddItemDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterInventory,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterInventory('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Summary
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildSummaryChip('Total Items', _inventory.length.toString()),
                  const SizedBox(width: 8),
                  _buildSummaryChip('Low Stock', _inventory.where((i) => i.stock < 10).length.toString()),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Inventory list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInventory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: AppTheme.textMuted.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No items in inventory',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!_isStaff)
                              ElevatedButton.icon(
                                onPressed: _showAddItemDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Item'),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInventory.length,
                          itemBuilder: (context, index) {
                            final item = _filteredInventory[index];
                            final isLowStock = item.stock < 10;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.item,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (isLowStock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.error.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Low Stock',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.error,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildInfoChip('Stock: ${item.stock}', 
                                            isLowStock ? AppTheme.error : AppTheme.success),
                                          const SizedBox(width: 8),
                                          _buildInfoChip('Cost: $currencySymbol${item.costPrice.toStringAsFixed(2)}', AppTheme.textSecondary),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Selling: $currencySymbol${item.sellingPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary.withOpacity(0.8),
                                        ),
                                      ),
                                      if (item.expiryDate != null && item.expiryDate!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildExpiryChip(item.expiryDate!),
                                      ],
                                    ],
                                  ),
                                ),
                                trailing: _isStaff
                                    ? null
                                    : PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditItemDialog(item);
                                          } else if (value == 'delete') {
                                            _deleteItem(item);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 20),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
                                                SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(color: AppTheme.error)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _isStaff
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label + ': ',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildExpiryChip(String expiryDate) {
    Color chipColor = AppTheme.success;
    String label = 'Expires: $expiryDate';

    try {
      final expiry = DateTime.parse(expiryDate);
      final now = DateTime.now();
      final diff = expiry.difference(now).inDays;

      if (diff < 0) {
        chipColor = AppTheme.error;
        label = 'Expired: $expiryDate';
      } else if (diff <= 7) {
        chipColor = AppTheme.error;
        label = 'Expires soon: $expiryDate';
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: chipColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Add Item Dialog
class AddItemDialog extends StatefulWidget {
  final String userId;
  final String currencySymbol;
  final VoidCallback onItemAdded;

  const AddItemDialog({
    super.key,
    required this.userId,
    required this.currencySymbol,
    required this.onItemAdded,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _shippingController = TextEditingController(text: '0');
  final _otherExpensesController = TextEditingController(text: '0');
  final _profitController = TextEditingController(text: '0');
  final _sellingController = TextEditingController();
  final _dbService = RemoteDatabaseService();
  bool _isLoading = false;
  DateTime? _expiryDate;

  double _parseAmount(String value) => double.tryParse(value.trim()) ?? 0.0;

  void _recalculateSellingPrice() {
    final cost = _parseAmount(_costController.text);
    final shipping = _parseAmount(_shippingController.text);
    final expenses = _parseAmount(_otherExpensesController.text);
    final profit = _parseAmount(_profitController.text);

    final autoPrice = cost + shipping + expenses + profit;
    _sellingController.text = autoPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _costController.dispose();
    _shippingController.dispose();
    _otherExpensesController.dispose();
    _profitController.dispose();
    _sellingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final item = InventoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: widget.userId,
        item: _nameController.text.trim(),
        stock: int.parse(_stockController.text),
        costPrice: double.parse(_costController.text),
        sellingPrice: double.parse(_sellingController.text),
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );

      await _dbService.addInventoryItem(item);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onItemAdded();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Stock is required';
                  if (int.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cost Price (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                onChanged: (_) => _recalculateSellingPrice(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Cost price is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shippingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Shipping Fee (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.local_shipping_outlined),
                ),
                onChanged: (_) => _recalculateSellingPrice(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Shipping fee is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otherExpensesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Other Expenses (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                ),
                onChanged: (_) => _recalculateSellingPrice(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Other expenses is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _profitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Preferred Profit (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.trending_up_outlined),
                ),
                onChanged: (_) => _recalculateSellingPrice(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Preferred profit is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sellingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Selling Price (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Selling price is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() => _expiryDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (Optional)',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: _expiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expiryDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _expiryDate != null
                        ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _expiryDate != null ? null : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add Item'),
        ),
      ],
    );
  }
}

// Edit Item Dialog
class EditItemDialog extends StatefulWidget {
  final InventoryItem item;
  final String currencySymbol;
  final VoidCallback onItemUpdated;

  const EditItemDialog({
    super.key,
    required this.item,
    required this.currencySymbol,
    required this.onItemUpdated,
  });

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.item.item);
  late final _stockController = TextEditingController(text: widget.item.stock.toString());
  late final _costController = TextEditingController(text: widget.item.costPrice.toString());
  late final _sellingController = TextEditingController(text: widget.item.sellingPrice.toString());
  final _dbService = RemoteDatabaseService();
  bool _isLoading = false;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    if (widget.item.expiryDate != null && widget.item.expiryDate!.isNotEmpty) {
      _expiryDate = DateTime.tryParse(widget.item.expiryDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedItem = widget.item.copyWith(
        item: _nameController.text.trim(),
        stock: int.parse(_stockController.text),
        costPrice: double.parse(_costController.text),
        sellingPrice: double.parse(_sellingController.text),
        expiryDate: _expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null,
      );

      await _dbService.updateInventoryItem(updatedItem);
      
      if (mounted) {
        Navigator.pop(context);
        widget.onItemUpdated();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Stock is required';
                  if (int.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cost Price (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Cost price is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sellingController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Selling Price (${widget.currencySymbol})',
                  prefixIcon: const Icon(Icons.sell_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Selling price is required';
                  if (double.tryParse(value) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() => _expiryDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (Optional)',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: _expiryDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expiryDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _expiryDate != null
                        ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _expiryDate != null ? null : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}
