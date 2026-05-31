import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';

class PricePilotScreen extends StatefulWidget {
  const PricePilotScreen({super.key});

  @override
  State<PricePilotScreen> createState() => _PricePilotScreenState();
}

class _PricePilotScreenState extends State<PricePilotScreen> {
  final _authService = AuthService();
  final _dbService = RemoteDatabaseService();

  User? _user;
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;
  String _filter = 'all';

  String get currencySymbol => _user?.currencySymbol ?? '₦';

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
      final result = await _dbService.getPricingAnalysis(user.id);
      if (mounted) {
        setState(() {
          _data = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_data == null || _data!['items'] == null) return [];
    final items = List<Map<String, dynamic>>.from(_data!['items']);
    if (_filter == 'low') {
      return items.where((i) => i['status'] == 'low').toList();
    }
    if (_filter == 'ok') {
      return items.where((i) => i['status'] == 'ok').toList();
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Pilot'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: AppTheme.error)),
          ],
        ),
      );
    }

    if (_data == null) {
      return const Center(child: Text('No data'));
    }

    if (_data!['error'] == 'INSUFFICIENT_DATA') {
      return _buildInsufficientData();
    }

    if (_data!['success'] != true) {
      return Center(child: Text(_data!['error']?.toString() ?? 'Unknown error'));
    }

    return _buildPricingView();
  }

  Widget _buildInsufficientData() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            'No Inventory Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Add inventory items in the Inventory screen to see pricing suggestions and margin analysis.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
            icon: const Icon(Icons.add),
            label: const Text('Add Inventory Items'),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingView() {
    final lowCount = _data!['low_margin_count'] ?? 0;
    final totalCount = _data!['total_items'] ?? 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          if (lowCount > 0)
            Card(
              color: AppTheme.error.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$lowCount of $totalCount items have low margin (under 20%).',
                        style: TextStyle(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              color: AppTheme.success.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: AppTheme.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All $totalCount items have healthy margins.',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Filter chips
          Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Needs Attention', 'low'),
              const SizedBox(width: 8),
              _buildFilterChip('Healthy', 'ok'),
            ],
          ),
          const SizedBox(height: 16),
          // Items list
          ..._filteredItems.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['item']?.toString() ?? 'Unknown';
    final cost = double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0;
    final sell = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0;
    final margin = double.tryParse(item['margin_percentage']?.toString() ?? '0') ?? 0;
    final status = item['status']?.toString() ?? 'ok';
    final suggested30 = double.tryParse(item['suggested_30']?.toString() ?? '0') ?? 0;
    final suggested50 = double.tryParse(item['suggested_50']?.toString() ?? '0') ?? 0;

    final isLow = status == 'low';
    final borderColor = isLow ? AppTheme.error : AppTheme.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: borderColor.withOpacity(0.1),
          child: Icon(
            isLow ? Icons.trending_down : Icons.trending_up,
            color: borderColor,
            size: 18,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Margin: ${margin.toStringAsFixed(1)}% | Sell: $currencySymbol${sell.toStringAsFixed(2)}',
          style: TextStyle(
            color: isLow ? AppTheme.error : AppTheme.success,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildDetailRow('Cost Price', '$currencySymbol${cost.toStringAsFixed(2)}'),
                _buildDetailRow('Current Sell Price', '$currencySymbol${sell.toStringAsFixed(2)}'),
                _buildDetailRow('Current Margin', '${margin.toStringAsFixed(1)}%'),
                const SizedBox(height: 8),
                Text(
                  'Suggested Prices:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                _buildDetailRow('30% margin', '$currencySymbol${suggested30.toStringAsFixed(2)}'),
                _buildDetailRow('50% margin', '$currencySymbol${suggested50.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
