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
  String? _createdLink;
  String? _createdTxRef;
  String? _smsStatus; // 'sending', 'sent', 'failed'
  String? _smsMessage;
  bool _isSendingSms = false;

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
          setState(() {
            _createdLink = link;
            _createdTxRef = txRef ?? '';
            _smsStatus = null;
            _smsMessage = null;
          });
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

  Future<void> _sendSms(String txRef, String phone) async {
    if (_user == null) return;
    setState(() {
      _isSendingSms = true;
      _smsStatus = 'sending';
      _smsMessage = null;
    });
    try {
      final response = await ApiService.post('/pos/payment-link/send-sms', {
        'user_id': _user!.id,
        'tx_ref': txRef,
        'phone_number': phone,
      });
      if (mounted) {
        if (response['success'] == true) {
          setState(() {
            _smsStatus = 'sent';
            _smsMessage = 'SMS sent successfully to ${response['phone'] ?? phone}';
          });
        } else {
          setState(() {
            _smsStatus = 'failed';
            _smsMessage = 'SMS failed: ${response['error']}';
          });
        }
        _loadPaymentLinks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _smsStatus = 'failed';
          _smsMessage = 'SMS failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  Future<bool?> _confirmPaymentDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: const Text('Did the customer complete the online payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Paid'),
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
            if (_createdLink != null) ...[
              const SizedBox(height: 16),
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.success),
                          const SizedBox(width: 8),
                          const Text('Payment Link Created', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: SelectableText(
                          _createdLink!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Ref: $_createdTxRef', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSendingSms
                                  ? null
                                  : () {
                                      final phone = _phoneController.text.trim();
                                      if (phone.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Enter a customer phone number first')),
                                        );
                                        return;
                                      }
                                      _sendSms(_createdTxRef!, phone);
                                    },
                              icon: _isSendingSms
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.sms),
                              label: Text(_isSendingSms ? 'Sending...' : 'Send SMS'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final paid = await _confirmPaymentDialog();
                                if (!context.mounted) return;
                                if (paid == true) {
                                  Navigator.pop(context, true);
                                }
                                // No → stay on this page; link stays visible
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_smsStatus != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _smsStatus == 'sent'
                                  ? Icons.check_circle
                                  : (_smsStatus == 'sending' ? Icons.hourglass_top : Icons.error),
                              size: 16,
                              color: _smsStatus == 'sent'
                                  ? AppTheme.success
                                  : (_smsStatus == 'sending' ? Colors.orange : AppTheme.error),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _smsMessage ?? (_smsStatus == 'sending' ? 'Sending SMS...' : ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _smsStatus == 'sent'
                                      ? AppTheme.success
                                      : (_smsStatus == 'sending' ? Colors.orange : AppTheme.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
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
                    '${link['customer_name'] ?? 'N/A'} • ${link['tx_ref'] ?? ''}'
                    '${link['sms_status'] != null ? ' • SMS: ${link['sms_status']}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.sms),
                        onPressed: () {
                          final phone = (link['customer_phone'] as String?)?.trim() ?? '';
                          if (phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No customer phone saved for this link')),
                            );
                            return;
                          }
                          _sendSms(link['tx_ref'] as String, phone);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_browser),
                        onPressed: () async {
                          final url = link['payment_link'] as String?;
                          if (url != null) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
                          }
                        },
                      ),
                    ],
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
