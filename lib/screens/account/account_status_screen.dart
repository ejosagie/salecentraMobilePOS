import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_logo.dart';

/// Full-screen gate shown when an account is expired or suspended.
/// Mirrors the web app behaviour: expired/trial-ended users are referred to
/// the upgrade page (with their email), suspended users are referred to support.
class AccountStatusScreen extends StatefulWidget {
  final User user;

  const AccountStatusScreen({super.key, required this.user});

  @override
  State<AccountStatusScreen> createState() => _AccountStatusScreenState();
}

class _AccountStatusScreenState extends State<AccountStatusScreen> {
  final _authService = AuthService();
  late User _user;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  bool get _isSuspended => _user.effectiveStatus == 'suspended';

  Future<void> _openUpgrade() async {
    final uri = Uri.https('salecentra.com', '/upgrade_account/', {
      'email': _user.email,
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open upgrade page')),
      );
    }
  }

  Future<void> _openSupport() async {
    final uri = Uri.parse(AppConstants.contactSupportUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open support page')),
      );
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    try {
      final updated = await _authService.getBusinessProfile(_user.id);
      if (!mounted) return;
      if (!updated.isAccessBlocked) {
        Navigator.pushReplacementNamed(
          context,
          updated.onboardingComplete ? '/dashboard' : '/onboarding',
        );
        return;
      }
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSuspended
              ? 'Your account is still suspended.'
              : 'Your subscription is still inactive.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh status: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = _isSuspended;
    final Color accent = suspended ? AppTheme.error : AppTheme.warning;
    final IconData icon = suspended ? Icons.block : Icons.workspace_premium_outlined;
    final String title = suspended ? 'Account Suspended' : 'Subscription Expired';
    final String message = suspended
        ? 'Your account has been suspended. Please contact our support team to resolve this and restore access.'
        : 'Your free trial or subscription has ended. Upgrade your plan to continue using SaleCentra and access your business data.';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 72),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 56, color: accent),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _user.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 32),
                if (Platform.isIOS) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      suspended
                          ? 'Your account status is suspended. Please manage your account using the service\'s standard account management channels.'
                          : 'Your subscription status is inactive. Please manage your account using the service\'s standard account management channels.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: suspended ? _openSupport : _openUpgrade,
                      icon: Icon(suspended ? Icons.support_agent : Icons.rocket_launch_outlined, size: 18),
                      label: Text(suspended ? 'Contact Support' : 'Upgrade Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _refreshStatus,
                    icon: _isRefreshing
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('I\'ve Updated My Plan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Log Out'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
