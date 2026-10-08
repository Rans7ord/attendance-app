import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../core/services/api_service.dart';
import '../../shared/widgets/pin_code_field.dart';
import '../../shared/widgets/selfie_capture_field.dart';
import '../dashboard/dashboard_screen.dart';

/// The "this isn't my phone" login path — no password, no trust in the
/// device. Email + PIN identify the account; the selfie is what actually
/// stands in for "I believe this is really them," since there's no OS lock
/// screen on someone else's phone to lean on.
class NotMyPhoneScreen extends StatefulWidget {
  const NotMyPhoneScreen({super.key});

  @override
  State<NotMyPhoneScreen> createState() => _NotMyPhoneScreenState();
}

class _NotMyPhoneScreenState extends State<NotMyPhoneScreen> {
  final _emailController = TextEditingController();
  final _pinKey = GlobalKey<PinCodeFieldState>();
  final _api = ApiService();

  XFile? _photo;
  bool _loading = false;
  String? _error;

  void _submit() async {
    final pin = _pinKey.currentState?.value ?? '';
    setState(() => _error = null);

    if (_emailController.text.isEmpty) {
      setState(() => _error = 'Enter your email');
      return;
    }
    if (pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit PIN');
      return;
    }
    if (_photo == null) {
      setState(() => _error = 'A selfie is required on a shared device');
      return;
    }

    setState(() => _loading = true);
    try {
      await _api.loginWithPin(email: _emailController.text, pin: pin, photo: _photo!);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on Object catch (e) {
      String message = 'Could not sign in — please try again';
      try {
        final data = (e as dynamic).response.data;
        final errors = data['errors'] as Map?;
        if (errors != null && errors.isNotEmpty) message = errors.values.first.first;
      } catch (_) {}
      setState(() => _error = message);
      _pinKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not My Phone')),
      body: SafeArea(
        child: Responsive.centeredForm(
          context,
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.phonelink_erase_outlined, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Using someone else\'s phone?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'A selfie is required every time on a shared device — no exceptions.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SelfieCaptureField(onChanged: (file) => setState(() => _photo = file)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                Text('Your PIN', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                PinCodeField(key: _pinKey, obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}