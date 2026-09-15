import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import '../../services/thermal_printer_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/offline_service.dart';
import '../../models/customer.dart';
import '../../models/inventory.dart';
import '../../models/sale.dart';
import '../../models/shop_order.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../payments/payment_screen.dart';

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
}

class SalesScreen extends StatefulWidget {
  final bool isStaffMode;
  final String? staffName;
  final bool isDefaultStaff;

  const SalesScreen({
    super.key,
    this.isStaffMode = false,
    this.staffName,
    this.isDefaultStaff = false,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  final _uuid = Uuid();
  final _offlineSync = OfflineSyncService();
  
  User? _user;
  List<InventoryItem> _inventory = [];
  List<CartItem> _cart = [];
  List<HeldCart> _heldCarts = [];
  List<CartItem> _lastCompletedSaleItems = [];
  String? _lastCompletedReceiptId;
  DateTime? _lastCompletedSaleDate;
  bool _isLoading = true;
  int _selectedIndex = 1; // 0 = Items, 1 = Cart, 2 = Orders (staff only)
  List<ShopOrder> _pendingOrders = [];
  bool _isLoadingOrders = false;
  final _productSearchController = TextEditingController();
  List<InventoryItem> _filteredInventory = [];

  // Customer fields
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  List<Customer> _customerSearchResults = [];
  bool _isSearchingCustomers = false;
  bool _showCustomerFields = false;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    final inventory = await _offlineSync.getInventoryWithFallback(user.id);

    setState(() {
      _user = user;
      _inventory = inventory.where((i) => i.stock > 0).toList();
      _filteredInventory = _inventory;
      _isLoading = false;
    });

    if (widget.isStaffMode && widget.isDefaultStaff) {
      _loadPendingOrders();
    }
  }

  Future<void> _loadPendingOrders() async {
    if (_user == null) return;
    setState(() => _isLoadingOrders = true);
    try {
      final orders = await _dbService.getShopOrders(_user!.id, status: 'pending');
      if (mounted) setState(() => _pendingOrders = orders);
    } catch (_) {
      // Silently fail — orders are a secondary feature for staff
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  Future<void> _completeOrder(ShopOrder order) async {
    if (_user == null) return;
    try {
      await _dbService.updateOrderStatus(_user!.id, order.id, 'completed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order completed and recorded as sales.'), backgroundColor: AppTheme.success),
        );
        _loadPendingOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _rejectOrder(ShopOrder order) async {
    if (_user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Text('Reject order from ${order.customerName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dbService.updateOrderStatus(_user!.id, order.id, 'cancelled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order rejected.'), backgroundColor: AppTheme.warning),
        );
        _loadPendingOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
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
      setState(() {
        item.quantity = newQty;
        final subtotal = item.unitPrice * item.quantity;
        if (item.discount > subtotal) {
          item.discount = subtotal;
        }
      });
    }
  }

  Future<void> _searchCustomers(String term) async {
    if (term.isEmpty || _user == null) {
      setState(() {
        _customerSearchResults = [];
        _isSearchingCustomers = false;
      });
      return;
    }

    setState(() => _isSearchingCustomers = true);
    try {
      final results = await _dbService.searchCustomers(_user!.id, term);
      if (mounted) {
        setState(() {
          _customerSearchResults = results;
          _isSearchingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingCustomers = false);
      }
    }
  }

  void _selectCustomer(Customer customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerNameController.text = customer.name;
      _customerPhoneController.text = customer.phone ?? '';
      _customerAddressController.text = customer.address ?? '';
      _customerSearchResults = [];
      _showCustomerFields = true;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerAddressController.clear();
      _customerSearchResults = [];
      _showCustomerFields = false;
    });
  }

  void _holdCurrentCart() {
    if (_cart.isEmpty) {
      _showError('Cart is empty — nothing to hold.');
      return;
    }
    final customerName = _customerNameController.text.trim();
    final label = customerName.isNotEmpty ? customerName : 'Cart ${_heldCarts.length + 1}';
    final held = HeldCart(
      id: _uuid.v4(),
      items: _cart
          .map((item) {
            final copy = CartItem(
              inventoryItem: item.inventoryItem,
              quantity: item.quantity,
              discount: item.discount,
            );
            if (item.hasCustomPrice) copy.unitPrice = item.unitPrice;
            return copy;
          })
          .toList(),
      customerName: customerName.isNotEmpty ? customerName : null,
      customerPhone: _customerPhoneController.text.trim().isNotEmpty
          ? _customerPhoneController.text.trim()
          : null,
      customerAddress: _customerAddressController.text.trim().isNotEmpty
          ? _customerAddressController.text.trim()
          : null,
      heldAt: DateTime.now(),
      label: label,
    );
    setState(() {
      _heldCarts.add(held);
      _cart.clear();
      _clearCustomer();
      _selectedIndex = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cart held for "$label". Start a new sale.'),
        backgroundColor: AppTheme.info,
        action: SnackBarAction(
          label: 'View Held',
          textColor: Colors.white,
          onPressed: _showHeldCartsDialog,
        ),
      ),
    );
  }

  void _resumeHeldCart(int index) {
    if (index < 0 || index >= _heldCarts.length) return;
    if (_cart.isNotEmpty) {
      _showError('Current cart must be empty or held before resuming another.');
      return;
    }
    final held = _heldCarts[index];
    final warnings = <String>[];

    // Refresh stock values from current inventory to avoid stale data
    for (final cartItem in held.items) {
      final match = _inventory.where((i) => i.id == cartItem.inventoryItem.id).firstOrNull;
      if (match != null) {
        cartItem.inventoryItem.stock = match.stock;
        if (cartItem.quantity > match.stock) {
          warnings.add('${cartItem.itemName}: only ${match.stock} left (cart has ${cartItem.quantity})');
          if (match.stock <= 0) {
            cartItem.quantity = 0;
          } else {
            cartItem.quantity = match.stock;
          }
        }
      } else {
        warnings.add('${cartItem.itemName}: no longer in inventory');
        cartItem.quantity = 0;
      }
    }

    // Remove items with zeroed-out quantity (no stock or missing)
    held.items.removeWhere((item) => item.quantity <= 0);

    if (held.items.isEmpty) {
      setState(() {
        _heldCarts.removeAt(index);
      });
      _showError('All items in this held cart are out of stock. Cart discarded.');
      return;
    }

    setState(() {
      _cart = held.items;
      if (held.customerName != null) {
        _customerNameController.text = held.customerName!;
        _showCustomerFields = true;
      }
      if (held.customerPhone != null) _customerPhoneController.text = held.customerPhone!;
      if (held.customerAddress != null) _customerAddressController.text = held.customerAddress!;
      _heldCarts.removeAt(index);
      _selectedIndex = 1;
    });

    if (warnings.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resumed with adjustments:\n${warnings.join('\n')}'),
          backgroundColor: AppTheme.warning,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resumed cart for "${held.label}".'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _deleteHeldCart(int index) {
    if (index < 0 || index >= _heldCarts.length) return;
    final held = _heldCarts[index];
    setState(() => _heldCarts.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Held cart "${held.label}" discarded.'),
        backgroundColor: AppTheme.warning,
      ),
    );
  }

  void _showHeldCartsDialog() {
    if (_heldCarts.isEmpty) {
      _showError('No held carts.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Held Carts (${_heldCarts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              if (_cart.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 18, color: AppTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Current cart has items. Hold or clear it before resuming another.',
                          style: TextStyle(fontSize: 12, color: AppTheme.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _heldCarts.length,
                  itemBuilder: (context, index) {
                    final held = _heldCarts[index];
                    final timeStr =
                        '${held.heldAt.hour.toString().padLeft(2, '0')}:${held.heldAt.minute.toString().padLeft(2, '0')}';
                    final itemCount = held.items.fold(0, (sum, item) => sum + item.quantity);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            '${held.items.length}',
                            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(held.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '$itemCount items · $currencySymbol${held.total.toStringAsFixed(2)} · Held at $timeStr',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill, color: AppTheme.success),
                              tooltip: 'Resume',
                              onPressed: () {
                                Navigator.pop(context);
                                _resumeHeldCart(index);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                              tooltip: 'Discard',
                              onPressed: () {
                                setModalState(() {});
                                _deleteHeldCart(index);
                                if (_heldCarts.isEmpty) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDiscountDialog(int index) async {
    final item = _cart[index];
    final controller = TextEditingController(
      text: item.discount > 0 ? item.discount.toStringAsFixed(2) : '',
    );
    final subtotal = item.unitPrice * item.quantity;

    final discount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discount for ${item.itemName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Discount amount',
            prefixText: currencySymbol,
            helperText: 'Maximum: $currencySymbol${subtotal.toStringAsFixed(2)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 0.0),
            child: const Text('Remove'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim()) ?? 0.0;
              if (value < 0 || value > subtotal) {
                _showError('Discount must be between 0 and $currencySymbol${subtotal.toStringAsFixed(2)}');
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (discount == null || !mounted) return;
    setState(() => item.discount = discount);
  }

  Future<void> _showEditPriceDialog(int index) async {
    final item = _cart[index];
    final controller = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );

    final newPrice = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price for ${item.itemName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Selling price',
            prefixText: currencySymbol,
            helperText: 'Original price: $currencySymbol${item.inventoryItem.sellingPrice.toStringAsFixed(2)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, -1.0),
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid price'), backgroundColor: AppTheme.error),
                );
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newPrice == null || !mounted) return;
    setState(() {
      if (newPrice == -1.0) {
        item.resetPrice();
      } else {
        item.unitPrice = newPrice;
      }
    });
  }

  double get totalAmount => _cart.fold(0, (sum, item) => sum + item.totalPrice);

  Future<String?> _showPaymentMethodDialog(double amount) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total: $currencySymbol${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _paymentMethodOption(
              icon: Icons.money,
              label: 'Cash',
              subtitle: 'Receive cash payment',
              value: 'cash',
            ),
            const Divider(),
            _paymentMethodOption(
              icon: Icons.credit_card,
              label: 'Online Payment',
              subtitle: 'Flutterwave payment link',
              value: 'online',
            ),
            const Divider(),
            _paymentMethodOption(
              icon: Icons.account_balance,
              label: 'Bank Transfer',
              subtitle: 'Direct bank transfer',
              value: 'bank_transfer',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pop(context, value),
    );
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      _showError('Cart is empty');
      return;
    }

    final saleTotal = totalAmount;
    final customerName = _customerNameController.text.trim();
    final customerPhone = _customerPhoneController.text.trim();

    // Show payment method selection dialog
    final paymentMethod = await _showPaymentMethodDialog(saleTotal);
    if (paymentMethod == null) return; // User cancelled

    if (paymentMethod == 'online') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            prefillAmount: saleTotal,
            prefillCustomerName: customerName.isNotEmpty ? customerName : null,
            prefillCustomerPhone: customerPhone.isNotEmpty ? customerPhone : null,
            prefillDescription: 'POS Sale - ${_cart.length} items',
          ),
        ),
      );
      // After returning from payment screen, complete the sale
    }

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final receiptId = _uuid.v4();
      _lastCompletedSaleItems = _cart
          .map((item) {
            final copy = CartItem(
              inventoryItem: item.inventoryItem,
              quantity: item.quantity,
              discount: item.discount,
            );
            if (item.hasCustomPrice) copy.unitPrice = item.unitPrice;
            return copy;
          })
          .toList();
      _lastCompletedReceiptId = receiptId;
      _lastCompletedSaleDate = now;
      
      final customerName = _customerNameController.text.trim();
      final customerPhone = _customerPhoneController.text.trim();
      final customerAddress = _customerAddressController.text.trim();
      
      bool hadOfflineSale = false;
      
      for (final cartItem in _cart) {
        // Record sale
        final sale = Sale(
          id: _uuid.v4(),
          userId: _user!.id,
          date: now,
          item: cartItem.itemName,
          quantity: cartItem.quantity,
          price: cartItem.unitPrice,
          discount: cartItem.discount,
          total: cartItem.totalPrice,
          costPrice: cartItem.inventoryItem.costPrice,
          enteredByStaffName: widget.isStaffMode ? widget.staffName : null,
          entryMode: widget.isStaffMode ? 'staff' : 'owner',
          customerName: customerName.isNotEmpty ? customerName : null,
          customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
          customerAddress: customerAddress.isNotEmpty ? customerAddress : null,
        );

        final newStock = cartItem.inventoryItem.stock - cartItem.quantity;

        try {
          await _dbService.recordSale(sale);
          // Update inventory
          await _dbService.updateStock(cartItem.inventoryItem.id, newStock);
        } catch (e) {
          // Network failed — save offline for later sync
          hadOfflineSale = true;
          await _offlineSync.saveOfflineSale(
            saleId: sale.id,
            userId: sale.userId,
            date: sale.date,
            item: sale.item,
            quantity: sale.quantity,
            price: sale.price,
            discount: sale.discount,
            total: sale.total,
            costPrice: sale.costPrice,
            enteredByStaffName: sale.enteredByStaffName,
            entryMode: sale.entryMode,
            customerName: sale.customerName,
            customerPhone: sale.customerPhone,
            customerAddress: sale.customerAddress,
            inventoryItemId: cartItem.inventoryItem.id,
            newStock: newStock,
          );
        }
      }

      if (mounted) {
        // Auto-print on Sunmi thermal printer
        _printSunmiReceipt(
          receiptId: receiptId,
          items: _lastCompletedSaleItems,
          customerName: customerName.isNotEmpty ? customerName : null,
          customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
        );
        _showReceiptDialog(
          customerName: customerName.isNotEmpty ? customerName : null,
          customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
          customerAddress: customerAddress.isNotEmpty ? customerAddress : null,
        );
        if (hadOfflineSale) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sale saved offline. It will sync automatically when back online.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error completing sale: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cart.clear();
          _isLoading = false;
          _clearCustomer();
        });
        _loadData();
      }
    }
  }

  Future<void> _printSunmiReceipt({
    required String? receiptId,
    required List<CartItem> items,
    String? customerName,
    String? customerPhone,
  }) async {
    if (_user == null || receiptId == null) return;
    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final discount = items.fold(0.0, (sum, item) => sum + item.discount);
    final total = subtotal;

    final thermalItems = items.map((item) => {
      'name': item.itemName,
      'quantity': item.quantity,
      'price': item.unitPrice,
    }).toList();

    await ThermalPrinterService.printReceipt(
      businessName: _user!.businessName,
      address: _user!.businessAddress,
      phone: _user!.phoneNumber,
      receiptNo: receiptId.substring(0, 8).toUpperCase(),
      cashier: widget.isStaffMode ? (widget.staffName ?? 'POS') : 'Owner',
      items: thermalItems,
      subtotal: subtotal,
      discount: discount,
      total: total,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  void _showReceiptDialog({
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    final soldItems = _lastCompletedSaleItems;
    final soldTotal = soldItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final receiptId = _lastCompletedReceiptId;
    final saleDate = _lastCompletedSaleDate;

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
          TextButton.icon(
            onPressed: () async {
              if (_user == null || receiptId == null || saleDate == null || soldItems.isEmpty) return;
              await PdfService.printThermalGroupedReceipt(
                receiptId: receiptId,
                date: saleDate,
                items: soldItems,
                user: _user!,
                enteredByStaffName: widget.isStaffMode ? widget.staffName : null,
                customerName: customerName,
                customerPhone: customerPhone,
                customerAddress: customerAddress,
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
          TextButton.icon(
            onPressed: () {
              _printSunmiReceipt(
                receiptId: receiptId,
                items: soldItems,
                customerName: customerName,
                customerPhone: customerPhone,
              );
            },
            icon: const Icon(Icons.receipt_outlined),
            label: const Text('Reprint (POS)'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (_user == null || receiptId == null || saleDate == null || soldItems.isEmpty) return;
              await PdfService.generateAndShareRichReceipt(
                receiptId: receiptId,
                date: saleDate,
                items: soldItems,
                user: _user!,
                enteredByStaffName: widget.isStaffMode ? widget.staffName : null,
                customerName: customerName,
                customerPhone: customerPhone,
                customerAddress: customerAddress,
              );
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
                _lastCompletedReceiptId = null;
                _lastCompletedSaleDate = null;
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
              if (_heldCarts.isNotEmpty)
                Expanded(
                  child: _buildTabButton('Held (${_heldCarts.length})', 3, Icons.pause_circle),
                ),
              if (widget.isStaffMode && widget.isDefaultStaff)
                Expanded(
                  child: _buildTabButton('Orders (${_pendingOrders.length})', 2, Icons.receipt_long_outlined),
                ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _selectedIndex == 0
              ? _buildItemsView()
              : _selectedIndex == 1
                  ? _buildCartView()
                  : _selectedIndex == 3
                      ? _buildHeldCartsView()
                      : _buildOrdersView(),
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
                    onPressed: _isLoading ? null : _holdCurrentCart,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Hold'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ).merge(ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.grey.shade100),
                      foregroundColor: WidgetStatePropertyAll(AppTheme.textPrimary),
                    )),
                  ),
                  const SizedBox(width: 8),
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

  Widget _buildHeldCartsView() {
    if (_heldCarts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_outline, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No held carts',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hold a cart from the Cart tab to park a sale',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _heldCarts.length,
      itemBuilder: (context, index) {
        final held = _heldCarts[index];
        final timeStr = '${held.heldAt.hour.toString().padLeft(2, '0')}:${held.heldAt.minute.toString().padLeft(2, '0')}';
        final itemCount = held.items.fold(0, (sum, item) => sum + item.quantity);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        held.label,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                    Text(
                      'Held at $timeStr',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$itemCount items · Total: $currencySymbol${held.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                if (held.customerName != null || held.customerPhone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (held.customerName != null) held.customerName!,
                      if (held.customerPhone != null) held.customerPhone!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _resumeHeldCart(index);
                        },
                        icon: const Icon(Icons.play_circle_fill, color: AppTheme.success),
                        label: const Text('Resume'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _deleteHeldCart(index));
                        },
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                        label: const Text('Discard'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                      ),
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

  void _filterProducts(String query) {
    setState(() {
      _filteredInventory = _inventory
          .where((item) => item.item.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _productSearchController,
            onChanged: _filterProducts,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _productSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _productSearchController.clear();
                        _filterProducts('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _filteredInventory.isEmpty
              ? Center(
                  child: Text(
                    'No products found',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _filteredInventory.length,
                  itemBuilder: (context, index) {
                    final item = _filteredInventory[index];
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
                ),
              ),
            ],
          );
  }

  Widget _buildCustomerSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Details (Optional)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_showCustomerFields || _customerNameController.text.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearCustomer,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  )
                else
                  TextButton.icon(
                    onPressed: () => setState(() => _showCustomerFields = true),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            if (_showCustomerFields || _customerNameController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Search or enter name',
                ),
                onChanged: (value) {
                  if (value.length >= 2) {
                    _searchCustomers(value);
                  } else {
                    setState(() => _customerSearchResults = []);
                  }
                },
              ),
              if (_isSearchingCustomers)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: LinearProgressIndicator(),
                ),
              if (_customerSearchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _customerSearchResults.map((customer) {
                      return ListTile(
                        dense: true,
                        title: Text(customer.name),
                        subtitle: customer.phone != null ? Text(customer.phone!) : null,
                        onTap: () => _selectCustomer(customer),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _customerPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerAddressController,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ],
        ),
      ),
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
      itemCount: _cart.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCustomerSection();
        }
        final cartIndex = index - 1;
        final item = _cart[cartIndex];
        final subtotal = item.unitPrice * item.quantity;
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
                          color: item.hasCustomPrice ? AppTheme.warning : AppTheme.textSecondary,
                        ),
                      ),
                      if (item.hasCustomPrice) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Original: $currencySymbol${item.inventoryItem.sellingPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                      if (item.discount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Discount: -$currencySymbol${item.discount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (!widget.isStaffMode)
                            OutlinedButton.icon(
                              onPressed: () => _showEditPriceDialog(cartIndex),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: Text(item.hasCustomPrice ? 'Edit Price' : 'Edit Price'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _showDiscountDialog(cartIndex),
                            icon: const Icon(Icons.local_offer_outlined, size: 16),
                            label: Text(item.discount > 0 ? 'Edit Discount' : 'Add Discount'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ],
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
                        onPressed: () => _updateQuantity(cartIndex, -1),
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => _updateQuantity(cartIndex, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.discount > 0)
                      Text(
                        '$currencySymbol${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Text(
                      '$currencySymbol${item.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                      onPressed: () => _removeFromCart(cartIndex),
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

  Widget _buildOrdersView() {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text('No pending online shop orders'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadPendingOrders,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingOrders.length,
        itemBuilder: (context, index) {
          final order = _pendingOrders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order #${order.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: const TextStyle(fontSize: 10, color: AppTheme.warning, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${order.customerName} · ${order.customerPhone}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  if (order.customerAddress != null && order.customerAddress!.isNotEmpty)
                    Text(order.customerAddress!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const Divider(),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${item.name} x${item.quantity}'),
                        Text('${order.currency} ${item.price.toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${order.notes}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _completeOrder(order),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Complete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectOrder(order),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
