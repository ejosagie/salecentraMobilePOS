import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../inventory/inventory_screen.dart';
import '../sales/sales_screen.dart';
import '../customers/customers_screen.dart';
import '../reports/reports_screen.dart';
import '../more/more_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _dbService = RemoteDatabaseService();
  
  User? _user;
  bool _isStaff = false;
  String? _staffName;
  int _selectedIndex = 0;
  bool _isLoading = true;

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initScreens();
    _loadUserData();
  }

  void _initScreens() {
    _screens = [
      _HomeScreen(onNavigateToTab: _onItemTapped),
      const InventoryScreen(),
      const SalesScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
      const MoreScreen(),
    ];
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    final isStaff = await _authService.isStaffLogin();
    final staffName = await _authService.getStaffName();
    
    setState(() {
      _user = user;
      _isStaff = isStaff;
      _staffName = staffName;
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Staff only sees Sales screen
    if (_isStaff) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${_user?.businessName ?? 'Business'} - Staff'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
        ),
        body: SalesScreen(isStaffMode: true, staffName: _staffName),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex > 3 ? 3 : _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 3) {
            // More menu
            _showMoreMenu();
          } else {
            _onItemTapped(index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Customers'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedIndex = 5);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Home Screen Widget
class _HomeScreen extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;

  const _HomeScreen({required this.onNavigateToTab});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final _authService = AuthService();
  final _dbService = RemoteDatabaseService();
  final _amountController = TextEditingController();
  
  User? _user;
  double _todaySales = 0;
  double _monthSales = 0;
  int _inventoryCount = 0;
  double _receivables = 0;
  double _payables = 0;
  Map<String, double>? _fxRates;
  bool _fxLoading = false;
  String? _fxError;
  String _fromCurrency = 'USD';
  String _toCurrency = 'NGN';
  double _conversionAmount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<Map<String, double>> _fetchFxRates() async {
    final response = await http.get(
      Uri.parse('https://open.er-api.com/v6/latest/USD'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch exchange rates');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = body['rates'];

    if (rates is! Map<String, dynamic>) {
      throw Exception('Invalid exchange rate response');
    }

    return rates.map((key, value) {
      if (value is num) {
        return MapEntry(key, value.toDouble());
      }
      return MapEntry(key, double.tryParse(value.toString()) ?? 0.0);
    });
  }

  Future<void> _loadFxRates() async {
    setState(() {
      _fxLoading = true;
      _fxError = null;
    });

    try {
      final rates = await _fetchFxRates();
      if (!mounted) return;
      setState(() {
        _fxRates = rates;
        _fxLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fxLoading = false;
        _fxError = 'Could not load live exchange rates';
      });
    }
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final todaySales = await _dbService.getTotalSales(user.id, startDate: today);
    final monthSales = await _dbService.getTotalSales(user.id, startDate: monthStart);
    final inventory = await _dbService.getInventory(user.id);
    final debtSummary = await _dbService.getDebtSummary(user.id);

    setState(() {
      _user = user;
      _todaySales = todaySales;
      _monthSales = monthSales;
      _inventoryCount = inventory.length;
      _receivables = debtSummary['owed_to_me'] ?? 0;
      _payables = debtSummary['i_owe'] ?? 0;
      _isLoading = false;
    });

    await _loadFxRates();
  }

  String get currencySymbol => _user?.currencySymbol ?? '₦';

  double? _rateToNgn(String currencyCode) {
    if (_fxRates == null || !_fxRates!.containsKey('NGN')) return null;
    if (currencyCode == 'NGN') return 1.0;

    final ngnPerUsd = _fxRates!['NGN']!;
    final targetPerUsd = _fxRates![currencyCode];
    if (targetPerUsd == null || targetPerUsd == 0) return null;
    return ngnPerUsd / targetPerUsd;
  }

  double? get _convertedAmount {
    if (_fxRates == null) return null;
    final fromRate = _fxRates![_fromCurrency];
    final toRate = _fxRates![_toCurrency];
    if (fromRate == null || toRate == null || fromRate == 0) return null;

    final usdValue = _conversionAmount / fromRate;
    return usdValue * toRate;
  }

  Widget _buildLiveExchangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Exchange Rates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Default view: NGN, EUR, USD, CNY',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            if (_fxLoading)
              const Center(child: CircularProgressIndicator())
            else if (_fxError != null)
              Text(
                _fxError!,
                style: const TextStyle(color: AppTheme.error),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildRateChip('NGN', _rateToNgn('NGN')),
                  _buildRateChip('EUR', _rateToNgn('EUR')),
                  _buildRateChip('USD', _rateToNgn('USD')),
                  _buildRateChip('CNY', _rateToNgn('CNY')),
                ],
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _fxLoading ? null : _loadFxRates,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Rates'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateChip(String code, double? value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null ? '--' : '₦${value.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyConverterCard() {
    final currencies = (_fxRates?.keys.toList() ?? ['USD', 'NGN'])..sort();

    if (!currencies.contains(_fromCurrency)) {
      _fromCurrency = currencies.first;
    }
    if (!currencies.contains(_toCurrency)) {
      _toCurrency = currencies.contains('NGN') ? 'NGN' : currencies.first;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Currency Converter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_fxRates == null)
              Text(
                _fxLoading ? 'Loading rates...' : 'Rates unavailable right now',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              )
            else ...[
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.calculate_outlined),
                ),
                onChanged: (value) {
                  setState(() {
                    _conversionAmount = double.tryParse(value) ?? 0;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fromCurrency,
                      decoration: const InputDecoration(labelText: 'From'),
                      items: currencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _fromCurrency = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _toCurrency,
                      decoration: const InputDecoration(labelText: 'To'),
                      items: currencies
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _toCurrency = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _convertedAmount == null
                      ? 'Converted amount: --'
                      : 'Converted amount: ${_toCurrency} ${_convertedAmount!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _user?.businessName ?? 'My Business',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Subscription status banner
                _buildSubscriptionBanner(),
                const SizedBox(height: 16),
                // Today's sales card
                _buildSalesCard(),
                const SizedBox(height: 16),
                // Quick stats
                _buildStatsGrid(),
                const SizedBox(height: 24),
                // Quick actions
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildLiveExchangeCard(),
                const SizedBox(height: 16),
                _buildCurrencyConverterCard(),
                const SizedBox(height: 24),
                // Recent activity header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Summary cards
                _buildSummaryCard(
                  'Inventory Items',
                  _inventoryCount.toString(),
                  Icons.inventory_2_outlined,
                  AppTheme.info,
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(
                  'Amount Owed to You',
                  '$currencySymbol${_receivables.toStringAsFixed(2)}',
                  Icons.account_balance_wallet_outlined,
                  AppTheme.success,
                ),
                const SizedBox(height: 12),
                _buildSummaryCard(
                  'Amount You Owe',
                  '$currencySymbol${_payables.toStringAsFixed(2)}',
                  Icons.money_off_outlined,
                  AppTheme.error,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Sales',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text(
                        '+12%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$currencySymbol${_todaySales.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This month: $currencySymbol${_monthSales.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    if (_user == null) return const SizedBox.shrink();

    // Active subscribers don't see the banner
    if (_user!.subscriptionStatus == 'active') {
      return const SizedBox.shrink();
    }

    // Check trial status
    final trialEnd = _user!.trialEnd;
    if (trialEnd == null) {
      return _buildExpiredBanner();
    }

    final now = DateTime.now();
    final daysRemaining = trialEnd.difference(now).inDays;

    if (daysRemaining < 0) {
      return _buildExpiredBanner();
    }

    // Show warning if 7 or fewer days remain
    final isUrgent = daysRemaining <= 7;

    return Card(
      color: isUrgent ? AppTheme.error.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUrgent ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: isUrgent ? AppTheme.error : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isUrgent ? 'Trial Expiring Soon!' : 'Free Trial',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isUrgent ? AppTheme.error : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              daysRemaining == 0
                  ? 'Your trial ends today. Upgrade now to keep using SaleCentra.'
                  : daysRemaining == 1
                      ? '1 day remaining on your trial. Upgrade to continue using all features.'
                      : '$daysRemaining days remaining on your trial.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openUpgradeLink,
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUrgent ? AppTheme.error : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredBanner() {
    return Card(
      color: AppTheme.error.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Trial Expired',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your free trial has ended. Upgrade to continue using SaleCentra.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openUpgradeLink,
                icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUpgradeLink() async {
    if (_user == null) return;

    final uri = Uri.https('salecentra.com', '/upgrade_account/', {
      'email': _user!.email,
    });

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open upgrade page')),
      );
    }
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Sales', '12', Icons.shopping_cart_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Items', _inventoryCount.toString(), Icons.inventory_2_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard('Customers', '8', Icons.people_outline),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'New Sale',
                Icons.point_of_sale,
                () => widget.onNavigateToTab(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Add Item',
                Icons.add_box,
                () => widget.onNavigateToTab(1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Add Customer',
                Icons.person_add,
                () => widget.onNavigateToTab(3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
