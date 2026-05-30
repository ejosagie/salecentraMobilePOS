import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  final _authService = AuthService();
  final _dbService = RemoteDatabaseService();

  int _selectedDays = 30;
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadForecast();
  }

  Future<void> _loadForecast() async {
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
      final result = await _dbService.getForecast(user.id, days: _selectedDays);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Forecast'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadForecast,
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

    return _buildForecastView();
  }

  Widget _buildInsufficientData() {
    final records = _data!['current_records'] ?? 0;
    final needed = _data!['records_needed'] ?? 14;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(Icons.insights_outlined, size: 80, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text(
            'Not Enough Sales Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You need at least $needed days of sales data to generate a forecast.\nYou currently have $records.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Record More Sales'),
          ),
          const SizedBox(height: 16),
          Text(
            'Come back after recording more sales.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastView() {
    final total = _data!['predicted_total']?.toStringAsFixed(2) ?? '0.00';
    final avg = _data!['predicted_average_daily']?.toStringAsFixed(2) ?? '0.00';
    final trend = _data!['trend_percentage'] as double? ?? 0.0;
    final busiest = _data!['busiest_day']?.toString() ?? 'Unknown';
    final slowest = _data!['slowest_day']?.toString() ?? 'Unknown';
    final records = _data!['records_used'] ?? 0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildToggleChip('7 Days', 7),
              const SizedBox(width: 12),
              _buildToggleChip('30 Days', 30),
            ],
          ),
          const SizedBox(height: 24),
          // Predicted Total
          _buildSummaryCard(
            'Predicted Revenue',
            '₦$total',
            Icons.trending_up,
            AppTheme.primaryColor,
            'Next $_selectedDays days',
          ),
          const SizedBox(height: 16),
          // Trend
          _buildSummaryCard(
            'Trend',
            '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
            trend >= 0 ? Icons.trending_up : Icons.trending_down,
            trend >= 0 ? AppTheme.success : AppTheme.error,
            'vs previous $_selectedDays days',
          ),
          const SizedBox(height: 16),
          // Daily Average
          _buildSummaryCard(
            'Average Daily Sales',
            '₦$avg',
            Icons.calendar_today,
            AppTheme.info,
            'Per day over next $_selectedDays days',
          ),
          const SizedBox(height: 16),
          // Busiest & Slowest
          Row(
            children: [
              Expanded(
                child: _buildSmallCard(
                  'Busiest Day',
                  busiest,
                  Icons.event,
                  AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallCard(
                  'Slowest Day',
                  slowest,
                  Icons.event,
                  AppTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Based on $records days of sales history',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, int days) {
    final isSelected = _selectedDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDays = days);
          _loadForecast();
        }
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
