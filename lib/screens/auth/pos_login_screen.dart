import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/update_service.dart';
import '../../services/pos_service.dart';
import '../../services/offline_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_logo.dart';
import '../settings/bank_details_screen.dart';

class PosLoginScreen extends StatefulWidget {
  const PosLoginScreen({super.key});

  @override
  State<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends State<PosLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _staffNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isStaffMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _staffNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isStaffMode) {
        await _authService.staffLogin(
          email: _emailController.text.trim(),
          staffName: _staffNameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        final user = await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (user == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login failed. Please try again.')),
            );
          }
          return;
        }

        // Check POS activation for owner
        final isOnline = await ConnectivityService.isOnline;
        if (isOnline) {
          final posStatus = await PosService.checkPosStatus(user.id);
          if (posStatus['pos_activated'] != true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('POS not activated for this account. Contact admin.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          // Register terminal if needed
          final terminalResult = await PosService.registerTerminal(user.id);
          final terminalId = terminalResult['terminal_id'];

          // Check bank details
          final hasBankDetails = posStatus['has_bank_details'] == true;
          if (!hasBankDetails && mounted) {
            final saved = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => BankDetailsScreen(userId: user.id)),
            );
            if (saved != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bank details required for POS settlement.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }
          }

          // Cache session for offline login
          await OfflineAuthService.cacheSession({
            'id': user.id,
            'email': user.email,
            'businessName': user.businessName,
            'businessAddress': user.businessAddress,
            'phoneNumber': user.phoneNumber,
            'currency': user.currency,
            'terminalId': terminalId,
          });
        }
      }

      if (mounted) {
        final canContinue = await UpdateService.showUpdateDialogIfNeeded(context);
        if (!mounted) return;
        if (canContinue) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                const AppIcon(size: 56),
                const SizedBox(height: 12),
                Text(
                  'SaleCentra POS',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Smart Sales Made Simple',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),

                // Toggle: Owner / Staff
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Owner'), icon: Icon(Icons.admin_panel_settings)),
                    ButtonSegment(value: true, label: Text('Staff'), icon: Icon(Icons.person)),
                  ],
                  selected: {_isStaffMode},
                  onSelectionChanged: (set) => setState(() => _isStaffMode = set.first),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Business Email',
                    prefixIcon: Icon(Icons.business_outlined),
                    hintText: 'owner@business.com',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter business email' : null,
                ),
                const SizedBox(height: 16),

                if (_isStaffMode) ...[
                  TextFormField(
                    controller: _staffNameController,
                    decoration: const InputDecoration(
                      labelText: 'Your Name (as configured)',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  keyboardType: _isStaffMode ? TextInputType.number : TextInputType.visiblePassword,
                  maxLength: _isStaffMode ? 6 : null,
                  decoration: InputDecoration(
                    labelText: _isStaffMode ? 'Passcode (PIN)' : 'Password',
                    prefixIcon: Icon(_isStaffMode ? Icons.pin_outlined : Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return _isStaffMode ? 'Enter passcode' : 'Enter password';
                    if (_isStaffMode && v.length < 4) return 'Passcode must be at least 4 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isStaffMode ? 'Sign In as Staff' : 'Sign In as Owner'),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openExternalLink(AppConstants.contactSupportUrl),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Contact Support'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
