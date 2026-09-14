import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/delivery_service.dart';
import '../../utils/theme.dart';
import '../../models/user.dart';
import 'delivery_book_screen.dart';
import 'delivery_detail_screen.dart';
import '../sales/returns_screen.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  User? _user;
  bool _isLoading = true;

  List<dynamic> _activeDeliveries = [];
  List<dynamic> _historyDeliveries = [];
  bool _isLoadingDeliveries = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _user = user;
      _isLoading = false;
    });
    if (user != null) {
      _loadDeliveries();
    }
  }

  Future<void> _loadDeliveries() async {
    if (_user == null) return;
    setState(() => _isLoadingDeliveries = true);
    try {
      final result = await DeliveryService.listDeliveries(userId: _user!.id);
      if (result['success'] == true) {
        final all = result['deliveries'] as List<dynamic>? ?? [];
        final activeStatuses = [
          'pending_payment',
          'confirmed',
          'assigned',
          'picked_up',
          'in_transit',
          'arrived_at_pickup',
          'arrived_at_dropoff'
        ];
        final historyStatuses = [
          'delivered',
          'completed',
          'successful',
          'cancelled'
        ];
        setState(() {
          _activeDeliveries = all
              .where((d) => activeStatuses.contains(d['status']))
              .toList();
          _historyDeliveries = all
              .where((d) => historyStatuses.contains(d['status']))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load deliveries: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingDeliveries = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries / Returns'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
            Tab(text: 'Book New'),
            Tab(text: 'Returns'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveTab(),
          _buildHistoryTab(),
          DeliveryBookScreen(
            user: _user!,
            onBooked: () {
              _loadDeliveries();
              _tabController.animateTo(0);
            },
          ),
          const ReturnsScreen(),
        ],
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_isLoadingDeliveries) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activeDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('No active deliveries',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text('Book a delivery'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeDeliveries.length,
        itemBuilder: (context, index) {
          final d = _activeDeliveries[index];
          return _buildDeliveryCard(d, isActive: true);
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingDeliveries) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('No delivery history',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyDeliveries.length,
        itemBuilder: (context, index) {
          final d = _historyDeliveries[index];
          return _buildDeliveryCard(d, isActive: false);
        },
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery,
      {required bool isActive}) {
    final status = delivery['status'] ?? 'unknown';
    final provider = delivery['provider'] ?? 'Unknown';
    final ref = delivery['gokada_reference'] ?? delivery['id']?.substring(0, 8);
    final pickupAddress = delivery['pickup_address'] ?? 'N/A';
    final dropoffAddress = delivery['dropoff_address'] ?? 'N/A';
    final customerFee = (delivery['customer_fee'] ?? 0).toDouble();
    final statusColor = _getStatusColor(status);
    final statusLabel = _formatStatus(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final deliveryId = delivery['id'];
          if (deliveryId == null) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryDetailScreen(deliveryId: deliveryId),
            ),
          );
          _loadDeliveries();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ref ?? 'N/A',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.my_location,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pickupAddress,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dropoffAddress,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (delivery['created_at'] != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(delivery['created_at']),
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.toString().isNotEmpty
                        ? provider[0].toUpperCase() + provider.substring(1)
                        : 'Unknown',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  Text(
                    '\u20a6${customerFee.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (isActive && delivery['pickup_otp'] != null && delivery['pickup_otp'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.password, size: 14, color: AppTheme.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'OTP: ${delivery['pickup_otp']}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isActive && status == 'pending_payment') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _initiatePayment(delivery['id']),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initiatePayment(String deliveryId) async {
    if (_user == null) return;
    try {
      final result = await DeliveryService.initiatePayment(
        deliveryId: deliveryId,
        email: _user!.email,
        customerName: _user!.businessName,
        customerPhone: _user!.phoneNumber,
      );
      if (result['success'] == true) {
        final paymentLink = result['payment_link'] as String?;
        if (paymentLink != null) {
          await launchUrl(Uri.parse(paymentLink),
              mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Payment opened in browser. Open the delivery to verify payment after completing.'),
              duration: Duration(seconds: 5),
            ),
          );
          await _loadDeliveries();
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    final dt = DateTime.tryParse(dateValue.toString());
    if (dt == null) return dateValue.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }
}
