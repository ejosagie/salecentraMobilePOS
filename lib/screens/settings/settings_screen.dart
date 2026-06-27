import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import 'business_settings_screen.dart';
import 'staff_settings_screen.dart';
import 'premium_staff_settings_screen.dart';
import '../notifications/notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _subscriptionStatus = 'trial';
  int? _daysRemaining;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final user = await AuthService().getCurrentUser();
    if (user != null) {
      setState(() {
        _subscriptionStatus = user.effectiveStatus;
        _endDate = _subscriptionStatus == 'active' ? user.subscriptionEnd : user.trialEnd;
        if (_endDate != null) {
          _daysRemaining = _endDate!.difference(DateTime.now()).inDays;
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
    if (_subscriptionStatus == 'suspended') {
      await _openSupportLink();
      return;
    }
    final uri = Uri.https('salecentra.com', '/upgrade_account/', {
      'email': user.email,
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open upgrade page')),
      );
    }
  }

  String get _subscriptionText {
    switch (_subscriptionStatus) {
      case 'active':
        return 'Active';
      case 'suspended':
        return 'Suspended';
      case 'expired':
        return 'Expired';
      default:
        if (_daysRemaining != null && _daysRemaining! >= 0 && _daysRemaining! <= 7) {
          return '$_daysRemaining days left';
        }
        return 'Trial';
    }
  }

  Color get _subscriptionColor {
    switch (_subscriptionStatus) {
      case 'active':
        return AppTheme.success;
      case 'suspended':
      case 'expired':
        return AppTheme.error;
      default:
        if (_daysRemaining != null && _daysRemaining! <= 7) return AppTheme.warning;
        return AppTheme.info;
    }
  }

  String get _subscriptionSubtitle {
    final dateText = _endDate != null
        ? 'Ends ${DateFormat('dd MMM yyyy').format(_endDate!)}'
        : '';
    switch (_subscriptionStatus) {
      case 'active':
        return dateText.isEmpty ? 'Plan: Active' : 'Plan: Active  •  $dateText';
      case 'suspended':
        return Platform.isIOS ? 'Account suspended' : 'Account suspended - Contact support';
      case 'expired':
        return Platform.isIOS ? 'Expired' : 'Expired - Upgrade now';
      default:
        return dateText.isEmpty ? 'Trial' : 'Trial  •  $dateText';
    }
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
              subtitle: _subscriptionSubtitle,
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
              onTap: Platform.isIOS
                  ? () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Account Status'),
                          content: const Text('To manage your business account and subscription status, go to salecentra.com'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                  : _openUpgradeLink,
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
              icon: Icons.groups_2_outlined,
              title: 'Premium Staff Settings',
              subtitle: 'Manage additional staff entry access',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumStaffSettingsScreen()),
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
                  'SaleCentra v1.0.16',
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
