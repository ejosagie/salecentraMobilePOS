import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../models/debt.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import 'package:uuid/uuid.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  final _uuid = Uuid();
  
  List<Debt> _debts = [];
  User? _user;
  bool _isLoading = true;
  String _selectedTab = 'all';
  final Map<String, bool> _expandedPayments = {};
  final Map<String, List<DebtPayment>> _paymentHistory = {};
  final Map<String, bool> _loadingPayments = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    String? type;
    if (_selectedTab == 'owed') type = 'receivable';
    if (_selectedTab == 'owe') type = 'payable';

    final debts = await _dbService.getDebts(user.id, type: type);
    await _dbService.getDebtSummary(user.id);

    setState(() {
      _user = user;
      _debts = debts;
      _isLoading = false;
    });
  }

  String get currencySymbol => _user?.currencySymbol ?? '₦';

  Future<void> _showAddDebtDialog() async {
    final result = await showDialog<_DebtData>(
      context: context,
      builder: (context) => AddDebtDialog(currencySymbol: currencySymbol),
    );

    if (result != null && _user != null) {
      final debt = Debt(
        id: _uuid.v4(),
        userId: _user!.id,
        type: result.type,
        amount: result.amount,
        balance: result.amount,
        description: result.description,
        dueDate: result.dueDate,
      );

      await _dbService.addDebt(debt);
      _loadData();
    }
  }

  Future<void> _recordPayment(Debt debt) async {
    final result = await showDialog<_PaymentData>(
      context: context,
      builder: (context) => RecordPaymentDialog(
        currencySymbol: currencySymbol,
        maxAmount: debt.balance,
      ),
    );

    if (result != null) {
      await _dbService.recordDebtPayment(debt.id, result.amount, note: result.note);
      _paymentHistory.remove(debt.id);
      _loadData();
    }
  }

  Future<void> _togglePaymentHistory(String debtId) async {
    final isExpanded = _expandedPayments[debtId] ?? false;
    setState(() {
      _expandedPayments[debtId] = !isExpanded;
    });
    if (!isExpanded && !_paymentHistory.containsKey(debtId)) {
      setState(() => _loadingPayments[debtId] = true);
      try {
        final payments = await _dbService.getDebtPayments(debtId);
        setState(() {
          _paymentHistory[debtId] = payments;
          _loadingPayments[debtId] = false;
        });
      } catch (_) {
        setState(() => _loadingPayments[debtId] = false);
      }
    }
  }

  List<Widget> _buildPaymentHistory(String debtId) {
    if (_loadingPayments[debtId] == true) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ];
    }
    final payments = _paymentHistory[debtId] ?? [];
    if (payments.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No payments recorded yet',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ),
      ];
    }
    return payments.map((p) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.success),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currencySymbol${p.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        DateFormat('MMM d, yyyy').format(p.date),
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  if (p.note != null && p.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        p.note!,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debts'),
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _selectedTab = ['all', 'owed', 'owe'][index];
                _isLoading = true;
              });
              _loadData();
            },
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Owed to Me'),
              Tab(text: 'I Owe'),
            ],
          ),
        ),
        body: _debts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'No debts recorded',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddDebtDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Debt'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _debts.length,
                  itemBuilder: (context, index) {
                    final debt = _debts[index];
                    final isReceivable = debt.type == 'receivable';
                    final isOverdue = debt.isOverdue;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isReceivable
                                        ? AppTheme.success.withOpacity(0.1)
                                        : AppTheme.error.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isReceivable ? 'Owed to You' : 'You Owe',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isReceivable ? AppTheme.success : AppTheme.error,
                                    ),
                                  ),
                                ),
                                if (debt.status == 'paid')
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.textMuted.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Paid',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                if (isOverdue && debt.status != 'paid')
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Overdue',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              debt.description ?? 'No description',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount: $currencySymbol${debt.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'Balance: $currencySymbol${debt.balance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: debt.balance > 0 ? AppTheme.textPrimary : AppTheme.success,
                                      ),
                                    ),
                                  ],
                                ),
                                if (debt.dueDate != null)
                                  Text(
                                    'Due: ${DateFormat('MMM d').format(debt.dueDate!)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isOverdue ? AppTheme.warning : AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _togglePaymentHistory(debt.id),
                                  icon: Icon(
                                    (_expandedPayments[debt.id] ?? false)
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 18,
                                  ),
                                  label: const Text('Payment History'),
                                ),
                                if (debt.balance > 0)
                                  TextButton.icon(
                                    onPressed: () => _recordPayment(debt),
                                    icon: const Icon(Icons.payment, size: 18),
                                    label: const Text('Record Payment'),
                                  ),
                              ],
                            ),
                            if (_expandedPayments[debt.id] ?? false) ..._buildPaymentHistory(debt.id),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDebtDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Debt'),
        ),
      ),
    );
  }
}

class _DebtData {
  final String type;
  final double amount;
  final String? description;
  final DateTime? dueDate;

  _DebtData({
    required this.type,
    required this.amount,
    this.description,
    this.dueDate,
  });
}

class _PaymentData {
  final double amount;
  final String? note;

  _PaymentData({required this.amount, this.note});
}

class AddDebtDialog extends StatefulWidget {
  final String currencySymbol;

  const AddDebtDialog({super.key, required this.currencySymbol});

  @override
  State<AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends State<AddDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'receivable';
  DateTime? _dueDate;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Debt'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'receivable', label: Text('Owed to Me')),
                  ButtonSegment(value: 'payable', label: Text('I Owe')),
                ],
                selected: {_type},
                onSelectionChanged: (selected) {
                  setState(() => _type = selected.first);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (${widget.currencySymbol}) *',
                  prefixIcon: const Icon(Icons.attach_money),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  if (double.tryParse(v) == null) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Due Date (optional)'),
                subtitle: Text(_dueDate != null
                    ? DateFormat('MMM d, yyyy').format(_dueDate!)
                    : 'No due date'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _DebtData(
                  type: _type,
                  amount: double.parse(_amountController.text),
                  description: _descriptionController.text.isEmpty
                      ? null
                      : _descriptionController.text,
                  dueDate: _dueDate,
                ),
              );
            }
          },
          child: const Text('Add Debt'),
        ),
      ],
    );
  }
}

class RecordPaymentDialog extends StatefulWidget {
  final String currencySymbol;
  final double maxAmount;

  const RecordPaymentDialog({
    super.key,
    required this.currencySymbol,
    required this.maxAmount,
  });

  @override
  State<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.maxAmount.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Remaining balance: ${widget.currencySymbol}${widget.maxAmount.toStringAsFixed(2)}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount (${widget.currencySymbol})',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                final amount = double.tryParse(v);
                if (amount == null) return 'Enter a valid amount';
                if (amount > widget.maxAmount) return 'Amount exceeds balance';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                _PaymentData(
                  amount: double.parse(_amountController.text),
                  note: _noteController.text.isEmpty ? null : _noteController.text,
                ),
              );
            }
          },
          child: const Text('Record Payment'),
        ),
      ],
    );
  }
}
