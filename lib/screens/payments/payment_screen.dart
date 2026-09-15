import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../models/user.dart';

class PaymentScreen extends StatefulWidget {
  final double? prefillAmount;
  final String? prefillCustomerName;
  final String? prefillCustomerPhone;
  final String? prefillDescription;

  const PaymentScreen({
    super.key,
    this.prefillAmount,
    this.prefillCustomerName,
    this.prefillCustomerPhone,
    this.prefillDescription,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  bool _isCreating = false;
  List<Map<String, dynamic>> _recentLinks = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _user = user;
      _isLoading = false;
      if (user != null) {
        _emailController.text = user.email;
        _nameController.text = widget.prefillCustomerName ?? user.businessName;
      }
      if (widget.prefillAmount != null) {
        _amountController.text = widget.prefillAmount!.toStringAsFixed(2);
      }
      if (widget.prefillCustomerPhone != null) {
        _phoneController.text = widget.prefillCustomerPhone!;
      }
      if (widget.prefillDescription != null) {
        _descriptionController.text = widget.prefillDescription!;
      }
    });
    if (user != null) {
      _loadPaymentLinks();
    }
  }

  Future<void> _loadPaymentLinks() async {
    if (_user == null) return;
    try {
      final response = await ApiService.get('/pos/payment-links', params: {
        'user_id': _user!.id,
      });
      if (response['success'] == true) {
        setState(() {
          _recentLinks = List<Map<String, dynamic>>.from(
            (response['payment_links'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _createPaymentLink() async {
    if (!_formKey.currentState!.validate() || _user == null) return;

    setState(() => _isCreating = true);
    try {
      final response = await ApiService.post('/pos/payment-link', {
        'user_id': _user!.id,
        'amount': double.parse(_amountController.text.trim()),
        'email': _emailController.text.trim(),
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'description': _descriptionController.text.trim(),
      });

      if (mounted) {
        final link = response['payment_link'] as String?;
        final txRef = response['tx_ref'] as String?;
        if (link != null) {
          _showLinkDialog(link, txRef ?? '');
          _amountController.clear();
          _descriptionController.clear();
          _loadPaymentLinks();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showLinkDialog(String link, String txRef) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Link Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link with your customer:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                link,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            Text('Ref: $txRef', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await launchUrl(Uri.parse(link), mode: LaunchMode.inAppBrowserView);
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Online Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payment, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          const Text('Request Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Generate a Flutterwave payment link for your customer.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '\u20a6',
                          border: const OutlineInputBorder(),
                          hintText: '0.00',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter amount';
                          final amt = double.tryParse(v);
                          if (amt == null || amt <= 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Phone (optional)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Customer Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter email';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCreating ? null : _createPaymentLink,
                          icon: _isCreating
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.link),
                          label: Text(_isCreating ? 'Creating...' : 'Create Payment Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_recentLinks.isNotEmpty) ...[
              const Text('Recent Payment Links', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._recentLinks.map((link) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (link['status'] == 'completed' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                    child: Icon(
                      link['status'] == 'completed' ? Icons.check_circle : Icons.pending,
                      color: link['status'] == 'completed' ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text('\u20a6${(link['amount'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}'),
                  subtitle: Text(
                    '${link['customer_name'] ?? 'N/A'} • ${link['tx_ref'] ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () async {
                      final url = link['payment_link'] as String?;
                      if (url != null) {
                        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
                      }
                    },
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
