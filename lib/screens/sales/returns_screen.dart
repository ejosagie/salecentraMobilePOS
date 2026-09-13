import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../models/sale.dart';
import '../../utils/theme.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  final _dbService = DatabaseService();
  final _remoteService = RemoteDatabaseService();
  final _authService = AuthService();
  List<Sale> _recentSales = [];
  bool _isLoading = true;
  String? _userId;
  String _currencySymbol = '₦';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      _userId = user?.id;
      if (user != null) {
        _currencySymbol = user.currencySymbol;
      }
      final allSales = await _dbService.getSales(_userId!);
      setState(() {
        _recentSales = allSales.where((s) => !s.isFullyRefunded).take(50).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processReturn(Sale sale) async {
    final amountController = TextEditingController(text: sale.total.toStringAsFixed(2));
    final reasonController = TextEditingController();
    String refundType = 'full';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Process Return'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: ${sale.item}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Total: $_currencySymbol${sale.total.toStringAsFixed(2)}'),
                if (sale.isPartiallyRefunded) ...[
                  const SizedBox(height: 4),
                  Text('Already refunded: $_currencySymbol${sale.refundedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppTheme.warning)),
                ],
                const SizedBox(height: 16),
                RadioListTile<String>(
                  title: const Text('Full refund'),
                  value: 'full',
                  groupValue: refundType,
                  onChanged: (v) => setState(() => refundType = v!),
                ),
                RadioListTile<String>(
                  title: const Text('Partial refund'),
                  value: 'partial',
                  groupValue: refundType,
                  onChanged: (v) => setState(() => refundType = v!),
                ),
                if (refundType == 'partial') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: 'Refund amount',
                      prefixText: _currencySymbol,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, {
                  'type': refundType,
                  'amount': refundType == 'full'
                      ? sale.total - sale.refundedAmount
                      : double.tryParse(amountController.text) ?? 0,
                  'reason': reasonController.text.trim(),
                });
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Process'),
            ),
          ],
        ),
      ),
    );

    if (result == null || _userId == null) return;

    try {
      await _remoteService.refundSale(
        saleId: sale.id,
        userId: _userId!,
        amount: result['amount'],
        reason: result['reason'],
        refundType: result['type'],
        refundedBy: 'POS',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return processed successfully'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Returns / Refunds')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentSales.isEmpty
              ? const Center(child: Text('No sales available for return'))
              : ListView.builder(
                  itemCount: _recentSales.length,
                  itemBuilder: (context, index) {
                    final sale = _recentSales[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(sale.item, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${sale.date.day}/${sale.date.month}/${sale.date.year} • $_currencySymbol${sale.total.toStringAsFixed(2)}'
                          '${sale.isPartiallyRefunded ? ' • Refunded: $_currencySymbol${sale.refundedAmount.toStringAsFixed(2)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.undo, color: Colors.red),
                          onPressed: () => _processReturn(sale),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
