import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/offline_service.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/theme.dart';
import '../inventory/inventory_screen.dart';
import '../sales/sales_screen.dart';
import '../sales/sales_history_screen.dart';
import '../sales/returns_screen.dart';
import '../deliveries/delivery_screen.dart';
import '../payments/payment_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/bank_details_screen.dart';
import '../../widgets/connection_status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  final _offlineSync = OfflineSyncService();
  bool _isLoading = true;
  bool _isStaff = false;
  String? _staffName;
  String? _userId;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _offlineSync.onSyncComplete = (remaining) {
      if (mounted) setState(() => _pendingSyncCount = remaining);
    };
    _offlineSync.startAutoSync();
    _checkPendingSync();
  }

  @override
  void dispose() {
    _offlineSync.stopAutoSync();
    super.dispose();
  }

  Future<void> _checkPendingSync() async {
    final count = await _offlineSync.getPendingSyncCount();
    if (mounted) setState(() => _pendingSyncCount = count);
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUser();
    final isStaff = await _authService.isStaffLogin();
    final staffName = await _authService.getStaffName();
    setState(() {
      _isStaff = isStaff;
      _staffName = isStaff ? staffName : 'Owner';
      _userId = user?.id;
      _isLoading = false;
    });
    // Cache inventory for offline use
    if (user != null) {
      _offlineSync.cacheInventory(user.id);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SaleCentra POS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Cashier: $_staffName', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_pendingSyncCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$_pendingSyncCount',
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const ConnectionStatusIndicator(isOnline: true),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => BankDetailsScreen(userId: _userId ?? ''),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnectionStatusBanner(),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(24),
              crossAxisCount: 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.0,
              children: [
                _PosMenuItem(
                  icon: Icons.point_of_sale,
                  label: 'Sales',
                  color: AppTheme.primaryColor,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SalesScreen(
                        isStaffMode: true,
                        staffName: _staffName,
                        isDefaultStaff: _isStaff,
                      ),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'History',
                  color: AppTheme.info,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const SalesHistoryScreen(),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Inventory',
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const InventoryScreen(),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'Deliver',
                  color: AppTheme.warning,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const DeliveryScreen(),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.undo,
                  label: 'Returns',
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ReturnsScreen(),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.payment,
                  label: 'Payment',
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PaymentScreen(),
                    ));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PosMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
