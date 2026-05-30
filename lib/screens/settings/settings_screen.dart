import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import 'business_settings_screen.dart';
import 'staff_settings_screen.dart';
import '../notifications/notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  Future<void> _openUpgradeLink() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return;
    // Placeholder: open web upgrade page
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
    return AppTheme.info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // Account section
            _buildSectionHeader(context, 'Account'),
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
                  color: _subscriptionColor.withValues(alpha: 0.1),
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
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
                  backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.error,
                ),
              ),
            ),

            // Version info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'SaleCentra v1.0.8',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
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
