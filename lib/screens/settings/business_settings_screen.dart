import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final _authService = AuthService();
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _industryController = TextEditingController();
  final _countryController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _phoneController.dispose();
    _contactPersonController.dispose();
    _industryController.dispose();
    _countryController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final current = await _authService.getCurrentUser();
    if (current == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final user = await _authService.getBusinessProfile(current.id);
      _businessNameController.text = user.businessName;
      _businessAddressController.text = user.businessAddress;
      _phoneController.text = user.phoneNumber;
      _contactPersonController.text = user.contactPerson;
      _industryController.text = user.industry;
      _countryController.text = user.country;

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null || !_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    try {
      final updated = await _authService.updateBusinessProfile(
        userId: _user!.id,
        businessName: _businessNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        industry: _industryController.text.trim(),
        country: _countryController.text.trim(),
      );

      if (mounted) {
        setState(() => _user = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business profile updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_user == null || !_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    try {
      await _authService.changePassword(
        userId: _user!.id,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing password: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _profileFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Business Profile', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _businessNameController,
                              decoration: const InputDecoration(labelText: 'Business Name'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _businessAddressController,
                              decoration: const InputDecoration(labelText: 'Business Address'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Phone Number'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contactPersonController,
                              decoration: const InputDecoration(labelText: 'Contact Person'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _industryController,
                              decoration: const InputDecoration(labelText: 'Industry'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _countryController,
                              decoration: const InputDecoration(labelText: 'Country'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSavingProfile ? null : _saveProfile,
                                child: _isSavingProfile
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Save Profile'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Change Password', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Current Password'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'New Password'),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 6) return 'Minimum 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Confirm New Password'),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v != _newPasswordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info),
                                onPressed: _isChangingPassword ? null : _changePassword,
                                child: _isChangingPassword
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Change Password'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
