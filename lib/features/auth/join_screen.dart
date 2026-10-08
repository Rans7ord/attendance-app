import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/selfie_capture_field.dart';
import '../dashboard/dashboard_screen.dart';
import '../../shared/widgets/pin_code_field.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _codeFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinKey = GlobalKey<PinCodeFieldState>();
  final _confirmPinKey = GlobalKey<PinCodeFieldState>();


  final _api = ApiService();

  String? _pinError;
  bool _loading = false;
  bool _checkingCode = false;
  bool _submitting = false;
  String? _companyName;
  bool _requireSelfie = true;
  List<dynamic> _branches = [];
  int? _selectedBranchId;
  XFile? _photo;

  void _lookupCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() {
      _checkingCode = true;
      _companyName = null;
      _branches = [];
      _selectedBranchId = null;
    });

    try {
      final data = await _api.getCompanyForJoinCode(_codeController.text.trim());
      setState(() {
        _companyName = data['company_name'];
        _requireSelfie = data['require_selfie_on_join'] ?? true;
        _branches = data['branches'] ?? [];
      });
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That code wasn\'t recognized, or it has expired')),
      );
    } finally {
      if (mounted) setState(() => _checkingCode = false);
    }
  }

  void _submit() async {
    if (!_detailsFormKey.currentState!.validate()) return;
    if (_requireSelfie && _photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This organization requires a selfie to join')),
      );
      return;
    }
    setState(() => _submitting = true);

    final pin = _pinKey.currentState?.value ?? '';
    final confirmPin = _confirmPinKey.currentState?.value ?? '';
    if (pin.length != 4) {
      setState(() => _pinError = 'Enter a 4-digit PIN');
      return;
    }
    if (pin != confirmPin) {
      setState(() => _pinError = 'PINs don\'t match');
      return;
    }
    setState(() => _pinError = null);

    setState(() => _loading = true);

    try {
      await _api.registerMember(
        joinCode: _codeController.text.trim(),
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        attendancePin: pin,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        branchId: _selectedBranchId,
        photo: _photo,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(Object e) {
    try {
      final data = (e as dynamic).response.data;
      final errors = data['errors'] as Map?;
      if (errors != null && errors.isNotEmpty) {
        return errors.values.first.first;
      }
      if (data['message'] != null) return data['message'];
    } catch (_) {}
    return 'Could not complete registration — please try again';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Join with a Code')),
      body: SafeArea(
        child: Responsive.centeredForm(
          context,
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.key_rounded, size: 38, color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Enter your organization\'s code',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _codeFormKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'Join code',
                              prefixIcon: Icon(Icons.tag_rounded),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            enabled: _companyName == null,
                            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (_companyName == null)
                          FilledButton(
                            onPressed: _checkingCode ? null : _lookupCode,
                            child: _checkingCode
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Check'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => setState(() {
                              _companyName = null;
                              _branches = [];
                              _selectedBranchId = null;
                              _photo = null;
                            }),
                            child: const Text('Change'),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_companyName != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Joining $_companyName',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (_requireSelfie) ...[
                    Center(
                      child: SelfieCaptureField(
                        onChanged: (file) => setState(() => _photo = file),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  Form(
                    key: _detailsFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: 'Your details',
                          icon: Icons.badge_rounded,
                          children: [
                            TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(labelText: 'First name'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(labelText: 'Last name'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(labelText: 'Phone (optional)'),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(labelText: 'Password'),
                              obscureText: true,
                              validator: (v) =>
                                  (v == null || v.length < 8) ? 'At least 8 characters' : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        _SectionCard(
                    title: 'Attendance PIN',
                    icon: Icons.pin_rounded,
                    children: [
                      Text(
                        'For signing in on a shared or borrowed device — see "Not My Phone" on the login screen.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(child: PinCodeField(key: _pinKey, onChanged: (_) => setState(() => _pinError = null))),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Confirm PIN', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.sm),
                      Center(child: PinCodeField(key: _confirmPinKey, onChanged: (_) => setState(() => _pinError = null))),
                      if (_pinError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(_pinError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                      ],
                    
                            if (_branches.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<int>(
                                initialValue: _selectedBranchId,
                                decoration: const InputDecoration(labelText: 'Branch (optional)'),
                                items: _branches
                                    .map<DropdownMenuItem<int>>((b) => DropdownMenuItem(
                                          value: b['id'],
                                          child: Text(b['name']),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedBranchId = v),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Join'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordered card wrapper grouping related fields with an icon + title
/// header, used to break long forms into digestible sections.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}