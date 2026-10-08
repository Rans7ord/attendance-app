import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../../shared/widgets/selfie_capture_field.dart';

const _industries = [
  'Business / Retail',
  'School / Education',
  'Church / Non-profit',
  'Healthcare',
  'Manufacturing / Warehouse',
  'Government',
  'Other',
];

class CompanySignupScreen extends StatefulWidget {
  const CompanySignupScreen({super.key});

  @override
  State<CompanySignupScreen> createState() => _CompanySignupScreenState();
}

class _CompanySignupScreenState extends State<CompanySignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _otherIndustryController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _attendancePinController = TextEditingController();
  final _confirmAttendancePinController = TextEditingController();
  String? _selectedIndustry;
  bool _loading = false;
  XFile? _photo;

  final _api = ApiService();

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Take a profile photo to create your admin account')),
      );
      return;
    }
    setState(() => _loading = true);

    final industry = _selectedIndustry == 'Other'
        ? _otherIndustryController.text
        : _selectedIndustry;

    try {
      await _api.registerCompany(
        companyName: _companyController.text,
        industry: (industry == null || industry.isEmpty) ? null : industry,
        adminName: _nameController.text,
        adminEmail: _emailController.text,
        adminPassword: _passwordController.text,
        adminAttendancePin: _attendancePinController.text,
        adminPhoto: _photo!,
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
      if (mounted) setState(() => _loading = false);
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
    return 'Could not create the company — please try again';
  }

  @override
  void dispose() {
    _companyController.dispose();
    _otherIndustryController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _attendancePinController.dispose();
    _confirmAttendancePinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Create Your Company')),
      body: SafeArea(
        child: Responsive.centeredForm(
          context,
          Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                      child: const Icon(Icons.apartment_rounded, size: 38, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Set up your organization',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You\'ll be the first admin — you can invite everyone else after this.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _SectionCard(
                    title: 'Organization',
                    icon: Icons.apartment_rounded,
                    children: [
                      TextFormField(
                        controller: _companyController,
                        decoration: const InputDecoration(labelText: 'Company / organization name'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedIndustry,
                        decoration: const InputDecoration(labelText: 'Industry (optional)'),
                        items: _industries
                            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedIndustry = v),
                      ),
                      if (_selectedIndustry == 'Other') ...[
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _otherIndustryController,
                          decoration: const InputDecoration(labelText: 'Tell us what kind'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _SectionCard(
                    title: 'Your admin account',
                    icon: Icons.person_rounded,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Your name'),
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
                    title: 'Kiosk attendance PIN',
                    icon: Icons.pin_rounded,
                    children: [
                      TextFormField(
                        controller: _attendancePinController,
                        decoration: const InputDecoration(
                          labelText: '4-digit attendance PIN',
                          helperText: 'Use this on a shared company clocking device.',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        validator: (v) => v != null && RegExp(r'^\d{4}$').hasMatch(v)
                            ? null
                            : 'Enter exactly 4 digits',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _confirmAttendancePinController,
                        decoration: const InputDecoration(labelText: 'Confirm attendance PIN'),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        validator: (v) => v == _attendancePinController.text
                            ? null
                            : 'PINs do not match',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: SelfieCaptureField(onChanged: (file) => setState(() => _photo = file)),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _handleSubmit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Company'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
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