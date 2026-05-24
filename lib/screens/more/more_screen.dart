import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../expenses/expenses_screen.dart';
import '../debts/debts_screen.dart';
import '../invoices/invoices_screen.dart';
import '../settings/business_settings_screen.dart';
import '../settings/staff_settings_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String _subscriptionStatus = 'trial';
  int? _daysRemaining;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final user = await AuthService().getCurrentUser();
    if (user != null) {
      setState(() {
        _subscriptionStatus = user.subscriptionStatus;
        if (user.trialEnd != null) {
          _daysRemaining = user.trialEnd!.difference(DateTime.now()).inDays;
        }
      });
    }
  }

  Future<void> _openUpgradeLink() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://salecentra.com/upgrade_account/'),
        body: {'email': user.email},
      );

      if (response.statusCode == 200) {
        // Open the upgrade page in browser
        final uri = Uri.parse('https://salecentra.com/upgrade_account/?email=${user.email}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        // Fallback: open directly with email parameter
        final uri = Uri.parse('https://salecentra.com/upgrade_account/?email=${user.email}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Fallback: open directly with email parameter
      final uri = Uri.parse('https://salecentra.com/upgrade_account/?email=${user.email}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openSupportLink() async {
    const url = 'https://salecentra.com/customer_tickets/';
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open support link')), 
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be available soon')),
    );
  }

  String get _subscriptionText {
    if (_subscriptionStatus == 'active') return 'Active';
    if (_daysRemaining == null || (_daysRemaining! < 0)) return 'Expired';
    if (_daysRemaining! <= 7) return '$_daysRemaining days left';
    return 'Trial';
  }

  Color get _subscriptionColor {
    if (_subscriptionStatus == 'active') return AppTheme.success;
    if (_daysRemaining == null || (_daysRemaining! < 0)) return AppTheme.error;
    if (_daysRemaining! <= 7) return AppTheme.warning;
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          // Business section
          _buildSectionHeader(context, 'Business'),
          _buildMenuItem(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'Invoices',
            subtitle: 'Manage customer invoices',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoicesScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Debts',
            subtitle: 'Track payables & receivables',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebtsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.money_off_outlined,
            title: 'Expenses',
            subtitle: 'Record business expenses',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              );
            },
          ),
          
          const Divider(),
          
          // Settings section
          _buildSectionHeader(context, 'Settings'),
          _buildMenuItem(
            context,
            icon: Icons.workspace_premium_outlined,
            title: 'Subscription',
            subtitle: _subscriptionStatus == 'active'
                ? 'Plan: Active'
                : _subscriptionText == 'Expired'
                    ? 'Trial expired - Upgrade now'
                    : 'Trial: $_subscriptionText',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _subscriptionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _subscriptionText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _subscriptionColor,
                ),
              ),
            ),
            onTap: _openUpgradeLink,
          ),
          _buildMenuItem(
            context,
            icon: Icons.store_outlined,
            title: 'Business Profile',
            subtitle: 'Update business information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BusinessSettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.badge_outlined,
            title: 'Staff Settings',
            subtitle: 'Configure sales entry access',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffSettingsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () => _showComingSoon('Notifications'),
          ),
          
          const Divider(),
          
          // Support section
          _buildSectionHeader(context, 'Support'),
          _buildMenuItem(
            context,
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: _openSupportLink,
          ),
          _buildMenuItem(
            context,
            icon: Icons.mail_outline,
            title: 'Contact Support',
            onTap: _openSupportLink,
          ),
          _buildMenuItem(
            context,
            icon: Icons.star_outline,
            title: 'Rate the App',
            onTap: () {},
          ),
          
          const Divider(),
          
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error.withOpacity(0.1),
                foregroundColor: AppTheme.error,
              ),
            ),
          ),
          
          // Version info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'SaleCentra v1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }
}
