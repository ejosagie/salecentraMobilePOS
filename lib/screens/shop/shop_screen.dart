import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../models/shop_settings.dart';
import '../../models/shop_product.dart';
import '../../models/shop_order.dart';
import '../../models/inventory.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _authService = AuthService();
  final _dbService = RemoteDatabaseService();

  User? _user;
  ShopSettings? _shopSettings;
  List<ShopProduct> _shopProducts = [];
  List<InventoryItem> _inventory = [];
  List<ShopOrder> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = 'Not logged in';
        });
        return;
      }
      _user = user;

      final results = await Future.wait([
        _dbService.getShopSettings(user.id),
        _dbService.getShopProducts(user.id),
        _dbService.getInventory(user.id),
        _dbService.getShopOrders(user.id),
      ]);

      setState(() {
        _shopSettings = results[0] as ShopSettings;
        _shopProducts = results[1] as List<ShopProduct>;
        _inventory = results[2] as List<InventoryItem>;
        _orders = results[3] as List<ShopOrder>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Online Shop'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Settings'),
              Tab(text: 'Products'),
              Tab(text: 'Subscription'),
              Tab(text: 'Orders'),
              Tab(text: 'Preview'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppTheme.error.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(_error!, style: TextStyle(color: AppTheme.error)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: TabBarView(
                      children: [
                        _ShopSettingsTab(
                          user: _user!,
                          settings: _shopSettings!,
                          dbService: _dbService,
                          onSaved: _loadData,
                        ),
                        _ShopProductsTab(
                          user: _user!,
                          settings: _shopSettings!,
                          products: _shopProducts,
                          inventory: _inventory,
                          dbService: _dbService,
                          onChanged: _loadData,
                        ),
                        _ShopSubscriptionTab(
                          user: _user!,
                          settings: _shopSettings!,
                          productCount: _shopProducts.length,
                        ),
                        _ShopOrdersTab(
                          user: _user!,
                          orders: _orders,
                          dbService: _dbService,
                          onChanged: _loadData,
                        ),
                        _ShopPreviewTab(settings: _shopSettings!),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ==================== SETTINGS TAB ====================

class _ShopSettingsTab extends StatefulWidget {
  final User user;
  final ShopSettings settings;
  final RemoteDatabaseService dbService;
  final VoidCallback onSaved;

  const _ShopSettingsTab({
    required this.user,
    required this.settings,
    required this.dbService,
    required this.onSaved,
  });

  @override
  State<_ShopSettingsTab> createState() => _ShopSettingsTabState();
}

class _ShopSettingsTabState extends State<_ShopSettingsTab> {
  late TextEditingController _nameController;
  late TextEditingController _slugController;
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountNameController;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _currencyController;
  late TextEditingController _currencySymbolController;
  late Color _themeColor;
  late bool _isActive;
  late bool _shopEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _nameController = TextEditingController(text: s.name);
    _slugController = TextEditingController(text: s.slug);
    _descriptionController = TextEditingController(text: s.description);
    _phoneController = TextEditingController(text: s.phone);
    _whatsappController = TextEditingController(text: s.whatsappNumber);
    _emailController = TextEditingController(text: s.email);
    _addressController = TextEditingController(text: s.address);
    _bankNameController = TextEditingController(text: s.bankName);
    _bankAccountNameController = TextEditingController(text: s.bankAccountName);
    _bankAccountNumberController = TextEditingController(text: s.bankAccountNumber);
    _currencyController = TextEditingController(text: s.currency);
    _currencySymbolController = TextEditingController(text: s.currencySymbol);
    _themeColor = _parseColor(s.themeColor);
    _isActive = s.isActive;
    _shopEnabled = s.shopEnabled;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    _currencyController.dispose();
    _currencySymbolController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF0066FF);
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final settings = ShopSettings(
        slug: _slugController.text.trim().toLowerCase(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        phone: _phoneController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        bankName: _bankNameController.text.trim(),
        bankAccountName: _bankAccountNameController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        currency: _currencyController.text.trim(),
        currencySymbol: _currencySymbolController.text.trim(),
        themeColor: _colorToHex(_themeColor),
        isActive: _isActive,
        shopEnabled: _shopEnabled,
      );
      await widget.dbService.saveShopSettings(widget.user.id, settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop settings saved successfully!'), backgroundColor: AppTheme.success),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop enabled toggle
          Card(
            child: SwitchListTile(
              title: const Text('Shop Enabled'),
              subtitle: const Text('Make your storefront visible to customers'),
              value: _shopEnabled,
              onChanged: (val) => setState(() => _shopEnabled = val),
            ),
          ),
          const SizedBox(height: 16),

          // Shop URL display
          if (_slugController.text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Shop URL', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  SelectableText(
                    'https://salecentra.com/shop/${_slugController.text}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Form fields
          _buildField('Shop Name', _nameController),
          _buildField('Shop Slug (URL name, one word)', _slugController, hint: 'e.g. myshop'),
          _buildField('Description', _descriptionController, maxLines: 3),
          _buildField('Phone', _phoneController),
          _buildField('WhatsApp Number', _whatsappController),
          _buildField('Email', _emailController),
          _buildField('Address', _addressController, maxLines: 2),
          const SizedBox(height: 16),
          const Text('Payment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildField('Bank Name', _bankNameController),
          _buildField('Account Name', _bankAccountNameController),
          _buildField('Account Number', _bankAccountNumberController),
          const SizedBox(height: 16),
          const Text('Currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Currency Code', _currencyController, hint: 'e.g. NGN')),
              const SizedBox(width: 12),
              Expanded(child: _buildField('Symbol', _currencySymbolController, hint: 'e.g. ₦')),
            ],
          ),
          const SizedBox(height: 16),

          // Theme color picker
          const Text('Theme Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final color = await showDialog<Color>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Pick Theme Color'),
                      content: SingleChildScrollView(
                        child: ColorPicker(currentColor: _themeColor),
                      ),
                    ),
                  );
                  if (color != null) setState(() => _themeColor = color);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _themeColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(_colorToHex(_themeColor), style: const TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),

          // Shop is live toggle
          Card(
            child: SwitchListTile(
              title: const Text('Shop is Live'),
              subtitle: const Text('Controls whether shop is accessible'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Shop Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// Simple color picker widget
class ColorPicker extends StatefulWidget {
  final Color currentColor;
  const ColorPicker({super.key, required this.currentColor});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  late Color _selected;

  static const List<Color> _presets = [
    Color(0xFF0066FF),
    Color(0xFF16A34A),
    Color(0xFFDC2626),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _presets.map((color) {
            final isSelected = _selected.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _selected = color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(color: AppTheme.textPrimary, width: 3) : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Select')),
          ],
        ),
      ],
    );
  }
}

// ==================== PRODUCTS TAB ====================

class _ShopProductsTab extends StatefulWidget {
  final User user;
  final ShopSettings settings;
  final List<ShopProduct> products;
  final List<InventoryItem> inventory;
  final RemoteDatabaseService dbService;
  final VoidCallback onChanged;

  const _ShopProductsTab({
    required this.user,
    required this.settings,
    required this.products,
    required this.inventory,
    required this.dbService,
    required this.onChanged,
  });

  @override
  State<_ShopProductsTab> createState() => _ShopProductsTabState();
}

class _ShopProductsTabState extends State<_ShopProductsTab> {
  bool _showAddSection = false;

  int get _productLimit => widget.settings.productLimit;
  int get _productCount => widget.products.length;

  List<InventoryItem> get _availableInventory {
    final shopInvIds = widget.products.map((p) => p.inventoryId).toSet();
    return widget.inventory.where((item) => !shopInvIds.contains(item.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product counter
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _productCount >= _productLimit
                  ? AppTheme.error.withOpacity(0.08)
                  : AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: _productCount >= _productLimit ? AppTheme.error : AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Products: $_productCount / $_productLimit',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _productCount >= _productLimit ? AppTheme.error : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Add from inventory section
          if (_productCount < _productLimit && _availableInventory.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAddSection = !_showAddSection),
              icon: Icon(_showAddSection ? Icons.expand_less : Icons.add),
              label: const Text('Add Products from Inventory'),
            ),
            if (_showAddSection) ...[
              const SizedBox(height: 12),
              ..._availableInventory.map((item) => _InventorySelectTile(
                    item: item,
                    onAdd: () => _addProduct(item),
                  )),
            ],
            const SizedBox(height: 16),
          ] else if (_productCount >= _productLimit) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: AppTheme.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Product limit reached. Upgrade your subscription to add more products.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Existing products
          if (widget.products.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No products in your shop yet.')))
          else
            ...widget.products.map((product) => _ProductCard(
                  product: product,
                  currencySymbol: widget.settings.currencySymbol,
                  onEdit: () => _editProduct(product),
                  onDelete: () => _deleteProduct(product),
                )),
        ],
      ),
    );
  }

  Future<void> _addProduct(InventoryItem item) async {
    try {
      await widget.dbService.addShopProduct(widget.user.id, {
        'inventory_id': item.id,
        'name': item.item,
        'price': item.sellingPrice,
        'stock': item.stock,
        'is_active': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.item} added to shop'), backgroundColor: AppTheme.success),
        );
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _editProduct(ShopProduct product) async {
    final result = await showDialog<ShopProduct>(
      context: context,
      builder: (context) => _EditProductDialog(product: product),
    );
    if (result != null) {
      try {
        await widget.dbService.updateShopProduct(widget.user.id, product.id, result.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated'), backgroundColor: AppTheme.success),
          );
          widget.onChanged();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  Future<void> _deleteProduct(ShopProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text('Remove ${product.name} from your shop?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.dbService.deleteShopProduct(widget.user.id, product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product removed from shop'), backgroundColor: AppTheme.success),
          );
          widget.onChanged();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }
}

class _InventorySelectTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onAdd;

  const _InventorySelectTile({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.item),
        subtitle: Text('Stock: ${item.stock} · Price: ${item.sellingPrice.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
          onPressed: onAdd,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ShopProduct product;
  final String currencySymbol;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.currencySymbol,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(product.imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: AppTheme.borderLight, child: const Icon(Icons.image, size: 24)))
                  : Container(width: 56, height: 56, color: AppTheme.borderLight, child: const Icon(Icons.image, size: 24)),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '$currencySymbol${product.price.toStringAsFixed(2)} · Stock: ${product.stock}',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: product.isActive ? AppTheme.success.withOpacity(0.1) : AppTheme.textMuted.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          product.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(fontSize: 10, color: product.isActive ? AppTheme.success : AppTheme.textMuted),
                        ),
                      ),
                      if (product.isOutOfStock) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Out of Stock', style: TextStyle(fontSize: 10, color: AppTheme.error)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _EditProductDialog extends StatefulWidget {
  final ShopProduct product;
  const _EditProductDialog({required this.product});

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _sortController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toStringAsFixed(2));
    _stockController = TextEditingController(text: widget.product.stock.toString());
    _sortController = TextEditingController(text: widget.product.sortOrder.toString());
    _isActive = widget.product.isActive;
  }

  @override
  void dispose() {
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _sortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sort Order', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, widget.product.copyWith(
              description: _descController.text.trim(),
              price: double.tryParse(_priceController.text) ?? widget.product.price,
              stock: int.tryParse(_stockController.text) ?? widget.product.stock,
              sortOrder: int.tryParse(_sortController.text) ?? widget.product.sortOrder,
              isActive: _isActive,
            ));
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

// ==================== SUBSCRIPTION TAB ====================

class _ShopSubscriptionTab extends StatelessWidget {
  final User user;
  final ShopSettings settings;
  final int productCount;

  const _ShopSubscriptionTab({
    required this.user,
    required this.settings,
    required this.productCount,
  });

  @override
  Widget build(BuildContext context) {
    final status = settings.subscriptionStatus;
    final isIOS = Platform.isIOS;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'active' ? Icons.check_circle : Icons.info_outline,
                        color: status == 'active' ? AppTheme.success : AppTheme.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'active' ? 'Subscription Active' : 'Free Plan',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (status == 'active') ...[
                    const Text('Your Shop Addon is active. You have unlimited products for your online storefront.'),
                    if (settings.subscriptionEndDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Valid until ${_formatDate(settings.subscriptionEndDate!)}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ] else if (status == 'pending')
                    const Text('Your Shop Addon request is pending admin approval. Your shop will be upgraded once the admin confirms your payment (usually within 48 hours).')
                  else
                    const Text('You are on the Free Shop plan (10 products). Subscribe for unlimited products for your business online storefront.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Product limit progress
          if (settings.productLimit > 0) ...[
            const Text('Product Usage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: productCount / settings.productLimit,
              backgroundColor: AppTheme.borderLight,
              color: productCount >= settings.productLimit ? AppTheme.error : AppTheme.primaryColor,
            ),
            const SizedBox(height: 4),
            Text('$productCount / ${settings.productLimit} products used',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
          ],

          // Upgrade section
          if (status != 'active') ...[
            if (!isIOS)
              const Text('Upgrade Your Shop', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (!isIOS) const SizedBox(height: 12),
            if (isIOS) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.info),
                    const SizedBox(height: 8),
                    const Text(
                      'To manage your shop add-on and account status, go to:',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'https://salecentra.com/',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchUrl('https://salecentra.com/'),
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Go to SaleCentra'),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.upgrade, color: AppTheme.primaryColor),
                    SizedBox(height: 8),
                    Text(
                      'Subscribe for unlimited products. Select "Shop Addons" on the subscription page.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _launchUrl('https://salecentra.com/subscribe/'),
                  icon: const Icon(Icons.payment),
                  label: const Text('Subscribe Now'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return isoDate.substring(0, 10);
    }
  }
}

// ==================== ORDERS TAB ====================

class _ShopOrdersTab extends StatefulWidget {
  final User user;
  final List<ShopOrder> orders;
  final RemoteDatabaseService dbService;
  final VoidCallback onChanged;

  const _ShopOrdersTab({
    required this.user,
    required this.orders,
    required this.dbService,
    required this.onChanged,
  });

  @override
  State<_ShopOrdersTab> createState() => _ShopOrdersTabState();
}

class _ShopOrdersTabState extends State<_ShopOrdersTab> {
  String _filter = 'All';

  List<ShopOrder> get _filteredOrders {
    if (_filter == 'All') return widget.orders;
    return widget.orders.where((o) => o.status.toLowerCase() == _filter.toLowerCase()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Completed', 'Cancelled'].map((filter) {
                final isSelected = _filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = filter);
                    },
                    selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Orders list
        Expanded(
          child: _filteredOrders.isEmpty
              ? const Center(child: Text('No orders found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredOrders.length,
                  itemBuilder: (context, index) => _OrderCard(
                    order: _filteredOrders[index],
                    onComplete: () => _updateStatus(_filteredOrders[index], 'completed'),
                    onCancel: () => _updateStatus(_filteredOrders[index], 'cancelled'),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _updateStatus(ShopOrder order, String status) async {
    try {
      await widget.dbService.updateOrderStatus(widget.user.id, order.id, status);
      if (mounted) {
        final statusMessages = {
          'completed': 'Order completed',
          'cancelled': 'Order cancelled',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(statusMessages[status] ?? 'Order updated'), backgroundColor: AppTheme.success),
        );
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  final ShopOrder order;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _OrderCard({required this.order, required this.onComplete, required this.onCancel});

  Color get _statusColor {
    switch (order.status) {
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status[0].toUpperCase() + order.status.substring(1),
                    style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Phone: ${order.customerPhone}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            if (order.customerEmail != null && order.customerEmail!.isNotEmpty)
              Text('Email: ${order.customerEmail}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('· ${item.name} x${item.quantity} - ${order.currency} ${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13)),
                )),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${order.currency} ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(order.paymentMethod, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            if (order.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== PREVIEW TAB ====================

class _ShopPreviewTab extends StatelessWidget {
  final ShopSettings settings;
  const _ShopPreviewTab({required this.settings});

  @override
  Widget build(BuildContext context) {
    final shopUrl = 'https://salecentra.com/shop/${settings.slug}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 80, color: AppTheme.primaryColor.withOpacity(0.5)),
            const SizedBox(height: 24),
            const Text('Your Online Shop', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (settings.slug.isNotEmpty) ...[
              const Text('Share your shop link with customers:', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(shopUrl, style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await launchUrl(Uri.parse(shopUrl), mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Open Shop'),
              ),
            ] else
              const Text('Set up your shop slug in Settings first.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
