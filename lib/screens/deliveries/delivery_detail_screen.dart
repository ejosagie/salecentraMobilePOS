import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/delivery_service.dart';
import '../../utils/theme.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final String deliveryId;

  const DeliveryDetailScreen({super.key, required this.deliveryId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  Map<String, dynamic>? _delivery;
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _isVerifying = false;
  String? _txRef;

  @override
  void initState() {
    super.initState();
    _loadDelivery();
  }

  Future<void> _loadDelivery() async {
    try {
      final result = await DeliveryService.getDelivery(widget.deliveryId);
      if (result['success'] == true) {
        setState(() {
          _delivery = result['delivery'];
          _isLoading = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load delivery: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelDelivery() async {
    setState(() => _isCancelling = true);
    try {
      final result = await DeliveryService.cancelDelivery(widget.deliveryId);
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery cancelled'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(result['error'] ?? 'Cancel failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancel failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Details')),
        body: const Center(child: Text('Delivery not found')),
      );
    }

    final d = _delivery!;
    final status = d['status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final isActive = !['delivered', 'completed', 'successful', 'cancelled']
        .contains(status);

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(d, status, statusColor),
            const SizedBox(height: 16),
            _buildInfoSection('Pickup', {
              'Address': d['pickup_address'],
              'Contact': d['pickup_name'],
              'Phone': d['pickup_phone'],
            }),
            const SizedBox(height: 16),
            _buildInfoSection('Dropoff', {
              'Address': d['dropoff_address'],
              'Contact': d['dropoff_name'],
              'Phone': d['dropoff_phone'],
            }),
            const SizedBox(height: 16),
            _buildInfoSection('Payment', {
              'Provider': d['provider'],
              'Customer Fee': '\u20a6${(d['customer_fee'] ?? 0).toStringAsFixed(0)}',
              'Status': _formatStatus(status),
              'Created': d['created_at'],
            }),
            if (d['rider_name'] != null) ...[
              const SizedBox(height: 16),
              _buildInfoSection('Rider', {
                'Name': d['rider_name'],
                'Phone': d['rider_phone'],
              }),
            ],
            if (d['notes'] != null && d['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoSection('Notes', {
                'Notes': d['notes'],
              }),
            ],
            const SizedBox(height: 24),
            if (isActive && status == 'pending_payment') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _initiatePayment(),
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_txRef != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isVerifying ? null : _verifyPayment,
                    icon: _isVerifying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified),
                    label: const Text('Verify Payment'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (isActive &&
                ['pending_payment', 'confirmed'].contains(status)) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : _cancelDelivery,
                  icon: _isCancelling
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Cancel Delivery',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      Map<String, dynamic> d, String status, Color statusColor) {
    final ref = d['gokada_reference'] ?? d['id']?.substring(0, 8);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reference',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                Text(ref ?? 'N/A',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatStatus(status),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, Map<String, dynamic> info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            ...info.entries.map((e) {
              final value = e.value?.toString();
              if (value == null || value.isEmpty || value == 'null') {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                    ),
                    Expanded(
                      child: Text(value,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _initiatePayment() async {
    try {
      final result = await DeliveryService.initiatePayment(
        deliveryId: widget.deliveryId,
        email: _delivery?['pickup_email'] ?? 'customer@salecentra.com',
        customerName: _delivery?['pickup_name'] ?? 'Customer',
        customerPhone: _delivery?['pickup_phone'] ?? '',
      );
      if (result['success'] == true) {
        final paymentLink = result['payment_link'] as String?;
        final txRef = result['tx_ref'] as String?;
        if (txRef != null) {
          setState(() => _txRef = txRef);
        }
        if (paymentLink != null) {
          await launchUrl(Uri.parse(paymentLink),
              mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment opened in browser. Tap "Verify Payment" after completing payment.'),
              duration: Duration(seconds: 5),
            ),
          );
          await _loadDelivery();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  Future<void> _verifyPayment() async {
    if (_txRef == null) return;
    setState(() => _isVerifying = true);
    try {
      final result = await DeliveryService.verifyPayment(txRef: _txRef!);
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment verified! Delivery confirmed.'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadDelivery();
        }
      } else {
        final msg = result['message'] ?? result['error'] ?? 'Verification failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
      case 'completed':
      case 'successful':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending_payment':
        return Colors.orange;
      case 'confirmed':
      case 'assigned':
        return Colors.blue;
      case 'picked_up':
      case 'in_transit':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
