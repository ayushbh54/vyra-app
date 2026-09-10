import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../theme.dart';

/// AUTH — Create Account / Sign In, one screen with a segmented switch,
/// matching the Stitch "Kinetic Authentication Matrix" design.
///
/// Google/Apple sign-in buttons are shown but disabled until real OAuth
/// credentials exist in .env (GOOGLE_OAUTH_CLIENT_ID etc.) — tapping them
/// explains why rather than silently failing.
class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.onAuthenticated, this.onDemoRequested, super.key});

  /// Called after a real signup/login succeeds — the parent decides whether
  /// to route into onboarding or straight home.
  final VoidCallback onAuthenticated;
  final VoidCallback? onDemoRequested;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { create, signIn }

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.create;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  double get _passwordStrength {
    final len = _passwordController.text.length;
    if (len == 0) return 0;
    if (len < 6) return 0.25;
    if (len < 8) return 0.5;
    if (len < 12) return 0.75;
    return 1.0;
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_mode == _Mode.create && name.isEmpty)) {
      setState(() => _error = 'Fill in every field to continue.');
      return;
    }
    if (_mode == _Mode.create && password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<VyraApi>();
      if (_mode == _Mode.create) {
        await api.signUp(name: name, email: email, password: password);
      } else {
        await api.logIn(email: email, password: password);
      }
      if (!mounted) return;
      widget.onAuthenticated();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final googleEmailController = TextEditingController(text: _emailController.text.trim());
    final googleNameController = TextEditingController(text: _nameController.text.trim());

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: VColor.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(VRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(VSpace.base, VSpace.base, VSpace.base, MediaQuery.of(ctx).viewInsets.bottom + VSpace.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.g_mobiledata, size: 28, color: VColor.accent),
                  SizedBox(width: 8),
                  Text('Continue with Google', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: VColor.text)),
                ],
              ),
              const SizedBox(height: VSpace.sm),
              const Text('Sign in or register your athlete profile seamlessly via Google.',
                  style: TextStyle(color: VColor.textMid, fontSize: 13)),
              const SizedBox(height: VSpace.base),
              TextField(
                controller: googleEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(
                  labelText: 'Google Account Email',
                  prefixIcon: Icon(Icons.alternate_email, color: VColor.textLow),
                ),
              ),
              const SizedBox(height: VSpace.sm),
              TextField(
                controller: googleNameController,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(
                  labelText: 'Athlete Name (optional)',
                  prefixIcon: Icon(Icons.person_outline, color: VColor.textLow),
                ),
              ),
              const SizedBox(height: VSpace.base),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VColor.accent,
                  foregroundColor: VColor.textOnAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Confirm Google Sign-In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (proceed != true || !mounted) return;
    final gEmail = googleEmailController.text.trim();
    if (gEmail.isEmpty || !gEmail.contains('@')) {
      setState(() => _error = 'Please enter a valid Google email address.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<VyraApi>();
      await api.logInWithGoogle(
        email: gEmail,
        name: googleNameController.text.trim().isNotEmpty ? googleNameController.text.trim() : null,
      );
      if (!mounted) return;
      widget.onAuthenticated();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    final newPasswordController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: VColor.surface,
          title: const Text('Reset Password', style: TextStyle(color: VColor.text, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your registered email and your new password (minimum 8 characters).',
                  style: TextStyle(color: VColor.textMid, fontSize: 13)),
              const SizedBox(height: VSpace.base),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(
                  labelText: 'Registered Email',
                  prefixIcon: Icon(Icons.email_outlined, color: VColor.textLow),
                ),
              ),
              const SizedBox(height: VSpace.sm),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline, color: VColor.textLow),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel', style: TextStyle(color: VColor.textLow)),
            ),
            ElevatedButton(
              onPressed: () async {
                final mail = resetEmailController.text.trim();
                final pass = newPasswordController.text;
                if (mail.isEmpty || pass.length < 8) return;
                try {
                  final msg = await context.read<VyraApi>().resetPassword(email: mail, newPassword: pass);
                  if (ctx.mounted) Navigator.of(ctx).pop(msg);
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: VColor.accent),
              child: const Text('Update Password'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _mode == _Mode.create;

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.bg,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VYRA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
            SizedBox(width: 6),
            Icon(Icons.circle, size: 6, color: VColor.accent),
          ],
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: VSpace.base),
            child: Icon(Icons.shield_outlined, color: VColor.textMid, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(VSpace.base, VSpace.sm, VSpace.base, VSpace.xl),
          children: [
            // Engine badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VColor.accentGlow,
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    border: Border.all(color: VColor.accent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: VColor.accent),
                      SizedBox(width: 6),
                      Text('VYRA ENGINE', style: TextStyle(
                          fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700, color: VColor.accent)),
                    ],
                  ),
                ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: VColor.good),
                    SizedBox(width: 4),
                    Text('SECURE', style: TextStyle(
                        fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700, color: VColor.good)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: VSpace.lg),

            // Hero heading
            const Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Step into the\n',
                    style: TextStyle(color: VColor.text, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
                TextSpan(text: 'VYRA Ecosystem',
                    style: TextStyle(color: VColor.accent, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
              ]),
            ),
            const SizedBox(height: VSpace.sm),
            const Text('Create your athlete profile or log in to sync your training history.',
                style: TextStyle(color: VColor.textMid, fontSize: 14)),
            const SizedBox(height: VSpace.lg),

            // Segmented switch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: VColor.surface,
                borderRadius: BorderRadius.circular(VRadius.lg),
                border: Border.all(color: VColor.line),
              ),
              child: Row(
                children: [
                  Expanded(child: _segmentButton('Create Account', isCreate, () => setState(() => _mode = _Mode.create))),
                  Expanded(child: _segmentButton('Sign In', !isCreate, () => setState(() => _mode = _Mode.signIn))),
                ],
              ),
            ),
            const SizedBox(height: VSpace.lg),

            // Google button
            OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 28, color: VColor.accent),
              label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: VColor.line),
                foregroundColor: VColor.text,
              ),
            ),
            const SizedBox(height: VSpace.lg),

            const Row(children: [
              Expanded(child: Divider(color: VColor.line)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: VSpace.sm),
                child: Text('OR CONTINUE WITH EMAIL', style: TextStyle(
                    color: VColor.textLow, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Divider(color: VColor.line)),
            ]),
            const SizedBox(height: VSpace.lg),

            if (isCreate) ...[
              _fieldLabel('Full name'),
              const SizedBox(height: VSpace.xs),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: VColor.text),
                decoration: const InputDecoration(
                  hintText: 'e.g. Alexis Vance',
                  prefixIcon: Icon(Icons.person_outline, color: VColor.textLow),
                ),
              ),
              const SizedBox(height: VSpace.base),
            ],

            _fieldLabel('Email'),
            const SizedBox(height: VSpace.xs),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: VColor.text),
              decoration: const InputDecoration(
                hintText: 'athlete@email.com',
                prefixIcon: Icon(Icons.alternate_email, color: VColor.textLow),
              ),
            ),
            const SizedBox(height: VSpace.base),

            _fieldLabel('Password'),
            const SizedBox(height: VSpace.xs),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: VColor.text),
              decoration: InputDecoration(
                hintText: '••••••••••••',
                prefixIcon: const Icon(Icons.lock_outline, color: VColor.textLow),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: VColor.textLow),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            if (isCreate) ...[
              const SizedBox(height: VSpace.sm),
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: _passwordStrength * 4 > i ? VColor.good : VColor.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 4),
                  ],
                ],
              ),
            ] else ...[
              const SizedBox(height: VSpace.xs),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _forgotPassword,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('Forgot Password?',
                      style: TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: VSpace.lg),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(VSpace.sm),
                decoration: BoxDecoration(
                  color: VColor.critSoft,
                  borderRadius: BorderRadius.circular(VRadius.md),
                ),
                child: Text(_error!, style: const TextStyle(color: VColor.crit, fontSize: 13)),
              ),
              const SizedBox(height: VSpace.base),
            ],

            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(VRadius.pill),
                  gradient: const LinearGradient(
                    colors: [VColor.accent, VColor.accentGreen],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ),
                  boxShadow: const [BoxShadow(color: VColor.accentGreenGlow, blurRadius: 18, spreadRadius: 1)],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(VRadius.pill),
                    onTap: _loading ? null : _submit,
                    child: Center(
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: VColor.textOnAccent))
                          : Text(isCreate ? 'Join VYRA' : 'Sign In',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: VColor.textOnAccent)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: VSpace.base),
            const Text(
              'By continuing, you agree to VYRA\'s data-encryption policy and athlete terms.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VColor.textLow, fontSize: 11),
            ),
            if (widget.onDemoRequested != null) ...[
              const SizedBox(height: VSpace.lg),
              Center(
                child: TextButton(
                  onPressed: widget.onDemoRequested,
                  child: const Text('Try a live demo instead',
                      style: TextStyle(color: VColor.accent, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segmentButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? VColor.accentGlow : Colors.transparent,
          borderRadius: BorderRadius.circular(VRadius.md),
          border: selected ? Border.all(color: VColor.accent.withValues(alpha: 0.4)) : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
            color: selected ? VColor.accent : VColor.textMid,
            fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text.toUpperCase(),
      style: const TextStyle(color: VColor.textMid, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w700));
}
