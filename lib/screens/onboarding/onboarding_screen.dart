import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user.dart';
import '../../models/inventory.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _authService = AuthService();
  final _dbService = RemoteDatabaseService();
  final _pageController = PageController();
  final _itemController = TextEditingController();
  final _stockController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();

  User? _user;
  String? _logoBase64;
  String _selectedCurrency = 'NGN';
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentPage = 0;
  final List<InventoryItem> _inventoryItems = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _itemController.dispose();
    _stockController.dispose();
    _costController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _logoBase64 = user?.logoBase64;
        _selectedCurrency = user?.currency ?? 'NGN';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _logoBase64 = base64Encode(bytes);
    });
  }

  void _addInventoryItem() {
    final item = _itemController.text.trim();
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final cost = double.tryParse(_costController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    if (item.isEmpty || stock <= 0 || cost <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all item fields correctly')),
      );
      return;
    }

    setState(() {
      _inventoryItems.add(InventoryItem(
        id: '',
        userId: _user!.id,
        item: item,
        stock: stock,
        costPrice: cost,
        sellingPrice: price,
      ));
      _itemController.clear();
      _stockController.clear();
      _costController.clear();
      _priceController.clear();
    });
  }

  Future<void> _finishOnboarding() async {
    if (_user == null) return;
    setState(() => _isSaving = true);

    try {
      // Save logo and currency to backend
      await _authService.updateBusinessProfile(
        userId: _user!.id,
        businessName: _user!.businessName,
        businessAddress: _user!.businessAddress,
        phoneNumber: _user!.phoneNumber,
        contactPerson: _user!.contactPerson,
        industry: _user!.industry,
        country: _user!.country,
        logoBase64: _logoBase64,
        currency: _selectedCurrency,
      );

      // Save inventory items
      for (final inv in _inventoryItems) {
        await _dbService.addInventoryItem(inv);
      }

      // Mark onboarding complete
      await _authService.completeOnboarding(_user!.id);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to SaleCentra'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildWelcomeStep(),
                _buildLogoStep(),
                _buildInventoryStep(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(onPressed: _prevPage, child: const Text('Back'))
                else
                  const SizedBox(),
                if (_currentPage < 2)
                  ElevatedButton(onPressed: _nextPage, child: const Text('Next'))
                else
                  ElevatedButton(
                    onPressed: _isSaving ? null : _finishOnboarding,
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Finish Setup'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppLogo(size: 80),
          const SizedBox(height: 24),
          Text(
            'Let\'s set up your business',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'We\'ll help you add your logo and first inventory items in just a few steps.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Business Details', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildDetailRow('Business Name', _user?.businessName ?? ''),
                  _buildDetailRow('Phone', _user?.phoneNumber ?? ''),
                  _buildDetailRow('Industry', _user?.industry ?? ''),
                  _buildDetailRow('Country', _user?.country ?? ''),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      prefixIcon: Icon(Icons.currency_exchange),
                    ),
                    items: AppConstants.currencySymbols.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text('${entry.value}  ${entry.key}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCurrency = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'You can update these anytime in Business Settings.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildLogoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Upload Business Logo',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This will appear on receipts and invoices.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: _logoBase64 != null && _logoBase64!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(base64Decode(_logoBase64!), fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload logo',
                          style: TextStyle(color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
            ),
          ),
          if (_logoBase64 != null && _logoBase64!.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => setState(() => _logoBase64 = null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove Logo'),
            ),
          ],
          const SizedBox(height: 24),
          const Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(
            'Your logo will be shown on printed receipts and PDF invoices.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Your First Inventory Items',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'You can skip this and add items later from the Inventory screen.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _itemController,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock Qty'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Cost Price'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Selling Price'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addInventoryItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_inventoryItems.isNotEmpty)
            Text('Added Items (${_inventoryItems.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._inventoryItems.map((item) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.inventory_2_outlined, size: 18),
              ),
              title: Text(item.item),
              subtitle: Text('Stock: ${item.stock} | Cost: ${_user?.currencySymbol ?? '₦'}${item.costPrice} | Sell: ${_user?.currencySymbol ?? '₦'}${item.sellingPrice}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => setState(() => _inventoryItems.remove(item)),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
