import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/premium_staff.dart';
import '../../services/auth_service.dart';
import '../../services/remote_database_service.dart';
import '../../utils/theme.dart';

class PremiumStaffSettingsScreen extends StatefulWidget {
  const PremiumStaffSettingsScreen({super.key});

  @override
  State<PremiumStaffSettingsScreen> createState() =>
      _PremiumStaffSettingsScreenState();
}

class _PremiumStaffSettingsScreenState
    extends State<PremiumStaffSettingsScreen> {
  final _dbService = RemoteDatabaseService();
  final _nameController = TextEditingController();
  final _passcodeController = TextEditingController();
  final _passcodeConfirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  User? _user;
  List<StaffAccount> _accounts = [];
  StaffSubscriptionStatus? _subStatus;
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passcodeController.dispose();
    _passcodeConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final current = await AuthService().getCurrentUser();
    if (current == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final accounts = await _dbService.getStaffAccounts(current.id);
      final status = await _dbService.getStaffSubscriptionStatus(current.id);
      if (mounted) {
        setState(() {
          _user = current;
          _accounts = accounts;
          _subStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _user = current;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading staff data: $e')),
        );
      }
    }
  }

  Future<void> _addStaff() async {
    if (_user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isAdding = true);
    try {
      await _dbService.createStaffAccount(
        _user!.id,
        _nameController.text.trim(),
        _passcodeController.text.trim(),
      );
      _nameController.clear();
      _passcodeController.clear();
      _passcodeConfirmController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff account added successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteStaff(StaffAccount account) async {
    if (_user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text('Remove ${account.staffName} from staff accounts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dbService.deleteStaffAccount(_user!.id, account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff account removed'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _openSubscribeLink() async {
    if (Platform.isIOS) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Premium Staff Add-on'),
          content: const Text(
            'To manage your Premium Staff Add-on and account status, go to salecentra.com',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    final uri = Uri.parse('https://salecentra.com/subscribe/addons.php');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Staff Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Manage additional staff entry access. Premium staff can log in to record sales using their own name and passcode.',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subscription status card
                    _buildSubscriptionCard(),
                    const SizedBox(height: 16),

                    // Staff list
                    Text('Staff Accounts', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_accounts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No premium staff accounts yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._accounts.map((account) => _buildStaffCard(account)),

                    const SizedBox(height: 16),

                    // Add staff form
                    if (_subStatus != null && _subStatus!.canAddMore)
                      _buildAddStaffForm()
                    else if (_subStatus != null && !_subStatus!.canAddMore)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Staff limit reached (${_subStatus!.currentCount}/${_subStatus!.staffLimit}). ${Platform.isIOS ? "Visit salecentra.com to upgrade." : "Upgrade your staff subscription to add more."}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSubscriptionCard() {
    final status = _subStatus;
    if (status == null) return const SizedBox.shrink();

    final tierText = status.subscription != null
        ? status.subscription!.tier[0].toUpperCase() + status.subscription!.tier.substring(1)
        : 'None';
    final expiryText = status.subscription != null
        ? 'Expires ${status.subscription!.endDate.substring(0, 10)}'
        : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subscription Status', style: TextStyle(fontWeight: FontWeight.w600)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.hasActiveSubscription
                        ? AppTheme.success.withOpacity(0.1)
                        : AppTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.hasActiveSubscription ? 'Active' : 'No Plan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.hasActiveSubscription ? AppTheme.success : AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Current Staff',
                    '${status.currentCount}',
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Staff Limit',
                    '${status.staffLimit}',
                    AppTheme.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Plan',
                    tierText,
                    AppTheme.success,
                  ),
                ),
              ],
            ),
            if (expiryText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(expiryText, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
            if (!status.hasActiveSubscription) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openSubscribeLink,
                  icon: Icon(Platform.isIOS ? Icons.info_outline : Icons.rocket_launch_outlined, size: 18),
                  label: Text(Platform.isIOS ? 'Account Status' : 'Subscribe to Premium Staff'),
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
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffAccount account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppTheme.primaryColor,
          child: Icon(Icons.person, color: Colors.white, size: 20),
        ),
        title: Text(account.staffName),
        subtitle: Text(
          account.createdAt != null
              ? 'Added ${account.createdAt!.substring(0, 10)}'
              : 'Staff account',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          onPressed: () => _deleteStaff(account),
        ),
      ),
    );
  }

  Widget _buildAddStaffForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Staff Account', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Staff Name',
                  hintText: 'Name staff will use during login',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Staff name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passcodeController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Staff Passcode',
                  hintText: '4 to 6 digits only',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final v = (value ?? '').trim();
                  if (v.isEmpty) return 'Passcode is required';
                  if (!RegExp(r'^\d{4,6}$').hasMatch(v)) {
                    return 'Passcode must be 4 to 6 digits only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passcodeConfirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Passcode',
                  hintText: 'Re-enter 4 to 6 digits',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != _passcodeController.text) {
                    return 'Passcodes do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _addStaff,
                  icon: _isAdding
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Add Staff Account'),
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
    );
  }
}
