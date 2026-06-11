import 'package:flutter/material.dart';
import '../../models/sale.dart';
import '../../models/expense.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  
  User? _user;
  List<Sale> _sales = [];
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _selectedPeriod = 'Today';

  final List<String> _periods = ['Today', 'This Week', 'This Month', 'This Year'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    DateTime? startDate;
    final now = DateTime.now();

    switch (_selectedPeriod) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        break;
    }

    final sales = await _dbService.getSales(user.id, startDate: startDate);
    final expenses = await _dbService.getExpenses(user.id);
    final filteredExpenses = expenses.where((e) => !e.date.isBefore(startDate!)).toList();

    setState(() {
      _user = user;
      _sales = sales;
      _expenses = filteredExpenses;
      _isLoading = false;
    });
  }

  String get currencySymbol => _user?.currencySymbol ?? '₦';

  double get grossSales => _sales.fold(0, (sum, s) => sum + (s.price * s.quantity));
  double get totalDiscounts => _sales.fold(0, (sum, s) => sum + s.discount);
  double get totalSales => _sales.fold(0, (sum, s) => sum + s.total);
  double get totalExpenses => _expenses.fold(0, (sum, e) => sum + e.amount);
  double get profit => totalSales - totalExpenses;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period selector
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _periods.length,
                  itemBuilder: (context, index) {
                    final period = _periods[index];
                    final isSelected = period == _selectedPeriod;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(period),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedPeriod = period;
                              _isLoading = true;
                            });
                            _loadData();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // Summary cards
              _buildSummaryCard(
                'Gross Sales',
                '$currencySymbol${grossSales.toStringAsFixed(2)}',
                Icons.trending_up,
                AppTheme.success,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'Total Discounts Given',
                '-$currencySymbol${totalDiscounts.toStringAsFixed(2)}',
                Icons.loyalty_outlined,
                AppTheme.warning,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'Net Sales',
                '$currencySymbol${totalSales.toStringAsFixed(2)}',
                Icons.point_of_sale,
                AppTheme.info,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'Total Expenses',
                '$currencySymbol${totalExpenses.toStringAsFixed(2)}',
                Icons.trending_down,
                AppTheme.error,
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'Net Profit',
                '$currencySymbol${profit.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                profit >= 0 ? AppTheme.success : AppTheme.error,
              ),
              const SizedBox(height: 24),
              // Recent sales
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Sales',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${_sales.length} transactions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_sales.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No sales in this period',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sales.length > 10 ? 10 : _sales.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sale = _sales[index];
                      return ListTile(
                        title: Text(sale.item),
                        subtitle: Text(
                          DateFormat('MMM d, h:mm a').format(sale.date),
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        trailing: Text(
                          '$currencySymbol${sale.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
