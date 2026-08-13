import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sale.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/theme.dart';


class SalesHistoryScreen extends StatefulWidget {
  final bool isStaffMode;
  final String? staffName;

  const SalesHistoryScreen({
    super.key,
    this.isStaffMode = false,
    this.staffName,
  });

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();

  User? _user;
  List<Sale> _filteredSales = [];
  bool _isLoading = true;
  String _selectedFilter = 'Today';

  final List<String> _filters = ['Today', 'This Week', 'This Month', 'All Time'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      DateTime? startDate;
      final now = DateTime.now();

      switch (_selectedFilter) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'This Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'This Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'All Time':
          startDate = null;
          break;
      }

      final sales = await _dbService.getSales(user.id, startDate: startDate);

      if (mounted) {
        setState(() {
          _user = user;
          _filteredSales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String get currencySymbol => _user?.currencySymbol ?? '₦';

  double get totalAmount => _filteredSales.fold(0, (sum, s) => sum + s.netTotal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History'),
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

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                          _isLoading = true;
                        });
                        _loadData();
                      }
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Summary bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredSales.length} sales',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                'Total: $currencySymbol${totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Sales list
        Expanded(
          child: _filteredSales.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredSales.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final sale = _filteredSales[index];
                    return _buildSaleCard(sale);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No sales in this period',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sales you record will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final hasDiscount = sale.discount > 0;
    final isRefunded = sale.isRefunded;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSaleOptions(sale),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isRefunded
                      ? AppTheme.warning.withValues(alpha: 0.1)
                      : AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isRefunded ? Icons.undo : Icons.receipt,
                  color: isRefunded ? AppTheme.warning : AppTheme.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.item,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sale.quantity} x $currencySymbol${sale.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Discount: -$currencySymbol${sale.discount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM d, yyyy  h:mm a').format(sale.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (sale.enteredByStaffName != null)
                      Text(
                        'Sold by: ${sale.enteredByStaffName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.info,
                        ),
                      ),
                    if (isRefunded) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sale.isFullyRefunded
                              ? AppTheme.error.withValues(alpha: 0.1)
                              : AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          sale.isFullyRefunded
                              ? 'FULLY REFUNDED'
                              : 'PARTIAL REFUND: $currencySymbol${sale.refundedAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: sale.isFullyRefunded ? AppTheme.error : AppTheme.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isRefunded) ...[
                    Text(
                      '$currencySymbol${sale.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currencySymbol${sale.netTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: sale.isFullyRefunded ? AppTheme.error : AppTheme.warning,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '$currencySymbol${sale.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Icon(Icons.share, size: 16, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaleOptions(Sale sale) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.receipt, color: AppTheme.primaryColor),
                title: const Text('View Receipt'),
                subtitle: Text('${sale.item} - $currencySymbol${sale.total.toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.pop(context);
                  _shareReceipt(sale);
                },
              ),
              if (sale.isRefunded) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppTheme.info),
                  title: const Text('View Refund Details'),
                  subtitle: Text(
                    sale.isFullyRefunded
                        ? 'Fully refunded: $currencySymbol${sale.refundedAmount.toStringAsFixed(2)}'
                        : 'Partially refunded: $currencySymbol${sale.refundedAmount.toStringAsFixed(2)}',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRefundDetails(sale);
                  },
                ),
              ],
              if (!widget.isStaffMode && !sale.isFullyRefunded) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.undo, color: AppTheme.warning),
                  title: const Text('Process Refund'),
                  subtitle: Text(
                    sale.isPartiallyRefunded
                        ? 'Refunded: $currencySymbol${sale.refundedAmount.toStringAsFixed(2)} / ${sale.total.toStringAsFixed(2)}'
                        : 'Full or partial refund',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRefundDialog(sale);
                  },
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Close'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareReceipt(Sale sale) async {
    if (_user == null) return;
    try {
      await PdfService.generateAndShareReceipt(sale, _user!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showRefundDialog(Sale sale) {
    final remaining = sale.total - sale.refundedAmount;
    final amountController = TextEditingController(text: remaining.toStringAsFixed(2));
    final notesController = TextEditingController();
    String refundType = 'full';
    String? selectedReason;

    const predefinedReasons = [
      'Customer returned item',
      'Wrong item sold',
      'Damaged goods',
      'Pricing error',
      'Customer changed mind',
      'Duplicate sale',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Process Refund'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: ${sale.item}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Sale total: $currencySymbol${sale.total.toStringAsFixed(2)}'),
                if (sale.isPartiallyRefunded) ...[
                  const SizedBox(height: 4),
                  Text('Already refunded: $currencySymbol${sale.refundedAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: AppTheme.warning)),
                ],
                const SizedBox(height: 4),
                Text('Remaining: $currencySymbol${remaining.toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Full'),
                        value: 'full',
                        groupValue: refundType,
                        onChanged: (v) => setState(() => refundType = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Partial'),
                        value: 'partial',
                        groupValue: refundType,
                        onChanged: (v) => setState(() => refundType = v!),
                      ),
                    ),
                  ],
                ),
                if (refundType == 'partial') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Refund amount',
                      prefixText: currencySymbol,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: predefinedReasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedReason = v),
                ),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Custom reason / notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
              onPressed: () {
                if (selectedReason == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a reason'), backgroundColor: AppTheme.error),
                  );
                  return;
                }
                final reason = selectedReason == 'Other'
                    ? notesController.text.trim()
                    : selectedReason;
                if (selectedReason == 'Other' && reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a custom reason'), backgroundColor: AppTheme.error),
                  );
                  return;
                }
                Navigator.pop(context);
                _processRefund(sale, refundType, amountController.text, reason);
              },
              child: const Text('Process Refund'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRefund(Sale sale, String refundType, String amountText, String reason) async {
    if (_user == null) return;

    double amount;
    if (refundType == 'full') {
      amount = sale.total - sale.refundedAmount;
    } else {
      amount = double.tryParse(amountText.trim()) ?? 0;
      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid refund amount'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }
      final remaining = sale.total - sale.refundedAmount;
      if (amount > remaining) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Amount exceeds remaining ($currencySymbol${remaining.toStringAsFixed(2)})'), backgroundColor: AppTheme.error),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      await _dbService.refundSale(
        saleId: sale.id,
        userId: _user!.id,
        amount: amount,
        reason: reason.isNotEmpty ? reason : null,
        refundType: refundType,
        refundedBy: widget.isStaffMode ? widget.staffName : 'owner',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refund of $currencySymbol${amount.toStringAsFixed(2)} processed'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _showRefundDetails(Sale sale) async {
    if (_user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading refund details...'),
          ],
        ),
      ),
    );

    try {
      final refunds = await _dbService.getRefunds(_user!.id);
      final saleRefunds = refunds.where((r) => r.saleId == sale.id).toList();

      if (mounted) Navigator.pop(context);

      if (saleRefunds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No refund records found for this sale')),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Refund Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: ${sale.item}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Sale total: $currencySymbol${sale.total.toStringAsFixed(2)}'),
                  Text('Refunded: $currencySymbol${sale.refundedAmount.toStringAsFixed(2)}'),
                  Text('Net: $currencySymbol${sale.netTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Divider(height: 24),
                  ...saleRefunds.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              r.isFull ? Icons.undo : Icons.remove_circle_outline,
                              size: 16,
                              color: r.isFull ? AppTheme.error : AppTheme.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${r.isFull ? "Full" : "Partial"} Refund',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Amount: $currencySymbol${r.amount.toStringAsFixed(2)}'),
                        if (r.reason != null && r.reason!.isNotEmpty)
                          Text('Reason: ${r.reason}'),
                        if (r.refundedBy != null)
                          Text('Processed by: ${r.refundedBy}'),
                        Text(
                          'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(r.refundedAt.toLocal())}',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
