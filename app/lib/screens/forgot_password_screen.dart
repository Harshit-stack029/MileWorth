import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Two-phase password reset. Phase 1 sends a reset email; phase 2 takes the
/// emailed token + a new password and signs the user back in.
///
/// The emailed link carries the token as a query parameter; until deep-linking
/// is wired, the user pastes the token here. In non-production the backend
/// echoes the token back so it can be prefilled for testing.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _sent = false; // moved to phase 2 once the email request succeeds

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_email.text.contains('@')) {
      _snack('Enter a valid email');
      return;
    }
    setState(() => _busy = true);
    try {
      final devToken = await context.read<AppState>().requestPasswordReset(_email.text);
      if (!mounted) return;
      setState(() {
        _sent = true;
        if (devToken != null) _token.text = devToken; // dev convenience
      });
      _snack('If that email exists, a reset link is on its way.');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_token.text.trim().isEmpty) {
      _snack('Paste the reset code from your email');
      return;
    }
    if (_password.text.length < 8) {
      _snack('Password must be at least 8 characters');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppState>().resetPassword(_token.text, _password.text);
      if (mounted) Navigator.pop(context); // AuthGate now shows the app
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _sent ? _phaseTwo() : _phaseOne(),
          ),
        ),
      ),
    );
  }

  Widget _phaseOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Enter your account email and we'll send you a link to reset your "
          'password.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _sendEmail,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send reset link'),
          ),
        ),
      ],
    );
  }

  Widget _phaseTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Check your email for a reset link, then paste the code from it below '
          'and choose a new password.',
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _token,
          minLines: 1,
          maxLines: 3,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Reset code',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _reset,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Set new password'),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _sendEmail,
          child: const Text('Resend email'),
        ),
      ],
    );
  }
}
