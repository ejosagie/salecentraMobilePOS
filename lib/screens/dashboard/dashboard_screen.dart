import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/offline_service.dart';
import '../../utils/theme.dart';
import '../inventory/inventory_screen.dart';
import '../sales/sales_screen.dart';
import '../sales/sales_history_screen.dart';
import '../deliveries/delivery_screen.dart';
import '../settings/bank_details_screen.dart';
import '../../widgets/connection_status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isStaff = false;
  String? _staffName;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
          const ConnectionStatusIndicator(isOnline: true),
          const SizedBox(width: 8),
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
                  label: 'Stock',
                  color: AppTheme.success,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const InventoryScreen(),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.local_shipping_outlined,
                  label: 'Deliver/Returns',
                  color: AppTheme.warning,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const DeliveryScreen(),
                    ));
                  },
                ),
                _PosMenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  color: AppTheme.textSecondary,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BankDetailsScreen(userId: _userId ?? ''),
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
