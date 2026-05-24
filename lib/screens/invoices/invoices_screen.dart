import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../services/pdf_service.dart';
import '../../models/invoice.dart';
import '../../models/customer.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  
  List<Invoice> _invoices = [];
  List<Customer> _customers = [];
  List<Invoice> _filteredInvoices = [];
  User? _user;
  bool _isLoading = true;
  String _selectedFilter = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return;

    setState(() {
      _user = user;
      _isLoading = true;
    });

    try {
      final invoices = await _dbService.getInvoices(user.id);
      final customers = await _dbService.getCustomers(user.id);
      
      setState(() {
        _invoices = invoices;
        _customers = customers;
        _filteredInvoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    }
  }

  void _filterInvoices(String query) {
    final normalizedQuery = query.trim().toLowerCase();

    setState(() {
      _filteredInvoices = _invoices.where((invoice) {
        final matchesSearch = normalizedQuery.isEmpty ||
            (invoice.notes?.toLowerCase().contains(normalizedQuery) ?? false) ||
            invoice.id.toLowerCase().contains(normalizedQuery) ||
            invoice.status.toLowerCase().contains(normalizedQuery) ||
            (invoice.customerId?.toLowerCase().contains(normalizedQuery) ?? false);
        final matchesFilter = _selectedFilter == 'all' || invoice.status == _selectedFilter;
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _applyStatusFilter(String status) {
    setState(() {
      _selectedFilter = status;
      _filterInvoices(_searchController.text);
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.success;
      case 'overdue':
        return AppTheme.error;
      case 'cancelled':
        return AppTheme.textMuted;
      default:
        return AppTheme.warning;
    }
  }

  Future<void> _showAddInvoiceDialog() async {
    final dueDateController = TextEditingController();
    final totalController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedCustomerId;
    DateTime? dueDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Invoice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Customer'),
                  value: selectedCustomerId,
                  items: _customers.map((customer) {
                    return DropdownMenuItem(
                      value: customer.id,
                      child: Text(customer.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCustomerId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDateController,
                  decoration: const InputDecoration(
                    labelText: 'Due Date (YYYY-MM-DD)',
                    hintText: 'Optional',
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      dueDate = date;
                      dueDateController.text = DateFormat('yyyy-MM-dd').format(date);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: totalController,
                  decoration: const InputDecoration(labelText: 'Total Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
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
              onPressed: () async {
                if (totalController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter total amount')),
                  );
                  return;
                }

                try {
                  final invoice = Invoice(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    userId: _user!.id,
                    customerId: selectedCustomerId,
                    date: DateTime.now(),
                    dueDate: dueDate,
                    total: double.parse(totalController.text),
                    status: 'unpaid',
                    notes: notesController.text.isEmpty ? null : notesController.text,
                  );

                  await _dbService.addInvoice(invoice);
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating invoice: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInvoiceDetails(Invoice invoice) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date:', DateFormat('yyyy-MM-dd').format(invoice.date)),
              _buildDetailRow('Due Date:', invoice.dueDate != null 
                  ? DateFormat('yyyy-MM-dd').format(invoice.dueDate!) 
                  : 'Not set'),
              _buildDetailRow('Total:', '₦${invoice.total.toStringAsFixed(2)}'),
              _buildDetailRow('Status:', invoice.status.toUpperCase()),
              if (invoice.notes != null) ...[
                const SizedBox(height: 8),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(invoice.notes!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (invoice.status == 'unpaid')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _markAsPaid(invoice),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark as Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await PdfService.generateAndShareInvoice(invoice, _user!);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (invoice.status == 'unpaid')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deleteInvoice(invoice),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                        ),
                      ),
                    ),
                ],
              ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(Invoice invoice) async {
    try {
      final updatedInvoice = Invoice(
        id: invoice.id,
        userId: invoice.userId,
        customerId: invoice.customerId,
        date: invoice.date,
        dueDate: invoice.dueDate,
        total: invoice.total,
        status: 'paid',
        notes: invoice.notes,
      );
      
      await _dbService.updateInvoice(updatedInvoice);
      Navigator.pop(context);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating invoice: $e')),
      );
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dbService.deleteInvoice(invoice.id);
        Navigator.pop(context);
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddInvoiceDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unpaid', 'unpaid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Paid', 'paid'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Overdue', 'overdue'),
                ],
              ),
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search invoices...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterInvoices,
            ),
          ),
          const SizedBox(height: 16),
          // Invoice list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No invoices found',
                              style: TextStyle(
                                fontSize: 18,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _filteredInvoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(invoice.status).withOpacity(0.1),
                                child: Icon(
                                  Icons.receipt_long,
                                  color: _getStatusColor(invoice.status),
                                ),
                              ),
                              title: Text(
                                '₦${invoice.total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('yyyy-MM-dd').format(invoice.date)),
                                  if (invoice.dueDate != null)
                                    Text('Due: ${DateFormat('yyyy-MM-dd').format(invoice.dueDate!)}'),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(invoice.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  invoice.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onTap: () => _showInvoiceDetails(invoice),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _applyStatusFilter(value);
        }
      },
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
    );
  }
}
