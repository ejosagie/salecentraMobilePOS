import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import '../../models/inventory.dart';
import '../../models/sale.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

class SalesScreen extends StatefulWidget {
  final bool isStaffMode;
  final String? staffName;

  const SalesScreen({
    super.key,
    this.isStaffMode = false,
    this.staffName,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  final _uuid = Uuid();
  
  User? _user;
  List<InventoryItem> _inventory = [];
  List<CartItem> _cart = [];
  List<CartItem> _lastCompletedSaleItems = [];
  bool _isLoading = true;
  int _selectedIndex = 1; // 0 = Items, 1 = Cart

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    final inventory = await _dbService.getInventory(user.id);

    setState(() {
      _user = user;
      _inventory = inventory.where((i) => i.stock > 0).toList();
      _isLoading = false;
    });
  }

  String get currencySymbol => _user?.currencySymbol ?? '₦';

  void _addToCart(InventoryItem item) {
    final existingIndex = _cart.indexWhere((c) => c.inventoryItem.id == item.id);
    
    if (existingIndex >= 0) {
      if (_cart[existingIndex].quantity < item.stock) {
        setState(() => _cart[existingIndex].quantity++);
      } else {
        _showError('Not enough stock available');
      }
    } else {
      setState(() => _cart.add(CartItem(inventoryItem: item)));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.item} added to cart (${_cart.length} item types)'),
        duration: const Duration(milliseconds: 900),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            if (mounted) {
              setState(() => _selectedIndex = 1);
            }
          },
        ),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQuantity(int index, int delta) {
    final item = _cart[index];
    final newQty = item.quantity + delta;
    
    if (newQty <= 0) {
      _removeFromCart(index);
    } else if (newQty > item.inventoryItem.stock) {
      _showError('Not enough stock available');
    } else {
      setState(() => item.quantity = newQty);
    }
  }

  double get totalAmount => _cart.fold(0, (sum, item) => sum + item.totalPrice);

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      _lastCompletedSaleItems = _cart
          .map((item) => CartItem(inventoryItem: item.inventoryItem, quantity: item.quantity))
          .toList();
      
      for (final cartItem in _cart) {
        // Record sale
        final sale = Sale(
          id: _uuid.v4(),
          userId: _user!.id,
          date: now,
          item: cartItem.itemName,
          quantity: cartItem.quantity,
          price: cartItem.unitPrice,
          total: cartItem.totalPrice,
          enteredByStaffName: widget.isStaffMode ? widget.staffName : null,
          entryMode: widget.isStaffMode ? 'staff' : 'owner',
        );

        await _dbService.recordSale(sale);

        // Update inventory
        final newStock = cartItem.inventoryItem.stock - cartItem.quantity;
        await _dbService.updateStock(cartItem.inventoryItem.id, newStock);
      }

      if (mounted) {
        _showReceiptDialog();
      }
    } catch (e) {
      _showError('Error completing sale: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cart.clear();
          _isLoading = false;
        });
        _loadData();
      }
    }
  }

  void _showReceiptDialog() {
    final soldItems = _lastCompletedSaleItems;
    final soldTotal = soldItems.fold(0.0, (sum, item) => sum + item.totalPrice);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sale Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
            const SizedBox(height: 16),
            Text(
              'Total: $currencySymbol${soldTotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${soldItems.length} item(s) sold',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              // Generate and share receipt for each item in cart
              for (var cartItem in soldItems) {
                final sale = Sale(
                  id: _uuid.v4(),
                  userId: _user!.id,
                  date: DateTime.now(),
                  item: cartItem.inventoryItem.item,
                  quantity: cartItem.quantity,
                  price: cartItem.inventoryItem.sellingPrice,
                  total: cartItem.inventoryItem.sellingPrice * cartItem.quantity,
                  enteredByStaffName: widget.staffName,
                  entryMode: widget.isStaffMode ? 'staff' : 'owner',
                );
                await PdfService.generateAndShareReceipt(sale, _user!);
              }
            },
            icon: const Icon(Icons.share),
            label: const Text('Share Receipt'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart.clear();
                _lastCompletedSaleItems.clear();
                _selectedIndex = 1;
              });
            },
            child: const Text('New Sale'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Staff indicator
          if (widget.isStaffMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.info.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, size: 16, color: AppTheme.info),
                const SizedBox(width: 8),
                Text(
                  'Staff Mode: ${widget.staffName}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        // Tab selector
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.borderLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton('Items', 0, Icons.inventory_2_outlined),
              ),
              Expanded(
                child: _buildTabButton('Cart (${_cart.length})', 1, Icons.shopping_cart_outlined),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _selectedIndex == 0
              ? _buildItemsView()
              : _buildCartView(),
        ),
        if (_selectedIndex == 0 && _cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 1),
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: Text('View Cart (${_cart.length})'),
                ),
              ),
            ),
          ),
        // Checkout bar
        if (_selectedIndex == 1 && _cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '$currencySymbol${totalAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _completeSale,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Complete Sale'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsView() {
    if (_inventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No items available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to inventory first',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _inventory.length,
      itemBuilder: (context, index) {
        final item = _inventory[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _addToCart(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.inventory_2,
                      size: 48,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.item,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currencySymbol${item.sellingPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stock: ${item.stock}',
                        style: TextStyle(
                          fontSize: 12,
                          color: item.stock < 10 ? AppTheme.error : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartView() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Cart is empty',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _selectedIndex = 0),
              child: const Text('Browse Items'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cart.length,
      itemBuilder: (context, index) {
        final item = _cart[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$currencySymbol${item.unitPrice.toStringAsFixed(2)} each',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: () => _updateQuantity(index, -1),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => _updateQuantity(index, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currencySymbol${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                      onPressed: () => _removeFromCart(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
