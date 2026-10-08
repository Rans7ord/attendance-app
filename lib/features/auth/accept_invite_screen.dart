import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/selfie_capture_field.dart';
import '../../shared/widgets/pin_code_field.dart';
import '../dashboard/dashboard_screen.dart';

/// If you later wire up email sending, the link in that email should deep
/// link straight here with [initialToken] pre-filled so the person only has
/// to set a name/password/selfie — no copy-pasting a token by hand.
class AcceptInviteScreen extends StatefulWidget {
  final String? initialToken;

  const AcceptInviteScreen({super.key, this.initialToken});

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenController;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinKey = GlobalKey<PinCodeFieldState>();
  final _confirmPinKey = GlobalKey<PinCodeFieldState>();
  String? _pinError;
  bool _loading = false;
  bool _checkingInvite = false;
  bool _inviteChecked = false;
  bool _requireSelfie = true;
  XFile? _photo;

  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_inviteChecked) {
      final isValidInvite = await _loadInvitePolicy();
      if (!isValidInvite) return;
    }
    if (_requireSelfie && _photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This organization requires a profile photo')),
      );
      return;
    }

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
      await _api.acceptInvite(
        token: _tokenController.text.trim(),
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        password: _passwordController.text,
        attendancePin: pin,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _loadInvitePolicy() async {
    if (_tokenController.text.trim().isEmpty) return false;
    setState(() => _checkingInvite = true);
    try {
      final details = await _api.getInviteRegistrationDetails(_tokenController.text.trim());
      if (!mounted) return false;
      setState(() {
        _requireSelfie = details['require_selfie_on_join'] ?? true;
        _inviteChecked = true;
        if (!_requireSelfie) _photo = null;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That invite link is invalid or expired')),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _checkingInvite = false);
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
    return 'Could not accept the invite — please try again';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Accept Invite')),
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
                      child: const Icon(Icons.mail_rounded, size: 38, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Set up your account',
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
                    child: TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'Invite link / token',
                        prefixIcon: const Icon(Icons.link_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Check invite',
                          onPressed: _checkingInvite ? null : _loadInvitePolicy,
                          icon: _checkingInvite
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        _inviteChecked = false;
                        _requireSelfie = true;
                        _photo = null;
                      }),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),

                  if (_inviteChecked) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Invite verified',
                              style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_inviteChecked && _requireSelfie) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: SelfieCaptureField(onChanged: (file) => setState(() => _photo = file)),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
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
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Accept Invite'),
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
