import 'package:flutter/material.dart';
import '../../services/remote_database_service.dart';
import '../../services/auth_service.dart';
import '../../models/customer.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import 'package:uuid/uuid.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _dbService = RemoteDatabaseService();
  final _authService = AuthService();
  final _uuid = Uuid();
  
  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  User? _user;
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final customers = await _dbService.getCustomers(user.id);
      if (!mounted) return;

      setState(() {
        _user = user;
        _customers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _user = user;
        _customers = [];
        _filteredCustomers = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customers: $e')),
      );
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _filteredCustomers = _customers
          .where((c) => c.name.toLowerCase().contains(query.toLowerCase()) ||
              (c.phone?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    });
  }

  Future<void> _showCustomerDialog({Customer? existing}) async {
    final result = await showDialog<Customer>(
      context: context,
      builder: (context) => CustomerDialog(customer: existing),
    );

    if (result == null || _user == null) return;

    if (existing != null) {
      await _dbService.updateCustomer(result);
    } else {
      final customer = Customer(
        id: _uuid.v4(),
        userId: _user!.id,
        name: result.name,
        email: result.email,
        phone: result.phone,
        address: result.address,
      );
      await _dbService.addCustomer(customer);
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCustomerDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCustomers,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterCustomers('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Summary
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildSummaryChip('Total', _customers.length.toString()),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Customers list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              'No customers yet',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showCustomerDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Customer'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  child: Text(
                                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                title: Text(customer.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (customer.phone != null && customer.phone!.isNotEmpty)
                                      Text(customer.phone!),
                                    if (customer.email != null && customer.email!.isNotEmpty)
                                      Text(
                                        customer.email!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                                isThreeLine: customer.email != null && customer.email!.isNotEmpty,
                                onTap: () => _showCustomerDialog(existing: customer),
                                trailing: const Icon(Icons.edit_outlined, size: 20),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Customer'),
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label + ': ',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerDialog extends StatefulWidget {
  final Customer? customer;
  const CustomerDialog({super.key, this.customer});

  @override
  State<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<CustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.customer?.name ?? '');
  late final _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
  late final _emailController = TextEditingController(text: widget.customer?.email ?? '');
  late final _addressController = TextEditingController(text: widget.customer?.address ?? '');

  bool get _isEditing => widget.customer != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Customer' : 'Add Customer'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                ),
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
                Customer(
                  id: widget.customer?.id ?? '',
                  userId: widget.customer?.userId ?? '',
                  name: _nameController.text.trim(),
                  phone: _phoneController.text.isEmpty ? null : _phoneController.text.trim(),
                  email: _emailController.text.isEmpty ? null : _emailController.text.trim(),
                  address: _addressController.text.isEmpty ? null : _addressController.text.trim(),
                  createdAt: widget.customer?.createdAt,
                ),
              );
            }
          },
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
