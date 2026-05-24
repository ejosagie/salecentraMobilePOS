import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _staffNameController = TextEditingController();
  final _passwordController = TextEditingController();

  User? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _staffNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final current = await _authService.getCurrentUser();
    if (current == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final settings = await _authService.getStaffSettings(current.id);
      if (mounted) {
        setState(() {
          _user = current;
          _enabled = settings['enabled'] == true;
          _staffNameController.text = (settings['staff_name'] ?? '').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _user = current;
          _enabled = current.salesEntryEnabled;
          _staffNameController.text = current.salesEntryStaffName ?? '';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading staff settings: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _authService.updateSalesEntrySettings(
        userId: _user!.id,
        enabled: _enabled,
        staffName: _staffNameController.text.trim(),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
      );

      _passwordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff settings updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating staff settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sales Entry Access', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable staff sales entry login'),
                          subtitle: const Text('Allow staff to login and record sales only'),
                          value: _enabled,
                          onChanged: (value) => setState(() => _enabled = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _staffNameController,
                          decoration: const InputDecoration(
                            labelText: 'Staff Name',
                            hintText: 'Name staff will use during login',
                          ),
                          validator: (value) {
                            if (!_enabled) return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Staff name is required when enabled';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: _enabled ? 'Set/Update Staff Passcode' : 'Optional Passcode Update',
                            hintText: 'At least 4 digits',
                          ),
                          validator: (value) {
                            final v = (value ?? '').trim();
                            if (_enabled && v.isEmpty && (_user?.salesEntryPasswordHash == null || _user!.salesEntryPasswordHash!.isEmpty)) {
                              return 'Passcode is required the first time you enable access';
                            }
                            if (v.isNotEmpty && v.length < 4) {
                              return 'Passcode must be at least 4 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Staff can only access sales entry with the configured business email, staff name, and passcode.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveSettings,
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save Staff Settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
