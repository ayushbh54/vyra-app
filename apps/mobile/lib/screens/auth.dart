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

  void _googleComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google sign-in needs an API key first — use email for now.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _mode == _Mode.create;

    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.bg,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
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
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Step into the\n',
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
              onPressed: _googleComingSoon,
              icon: const Icon(Icons.g_mobiledata, size: 22),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: VColor.line),
                foregroundColor: VColor.text,
              ),
            ),
            const SizedBox(height: VSpace.lg),

            Row(children: [
              const Expanded(child: Divider(color: VColor.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VSpace.sm),
                child: Text('OR CONTINUE WITH EMAIL', style: TextStyle(
                    color: VColor.textLow, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
              ),
              const Expanded(child: Divider(color: VColor.line)),
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
                  boxShadow: [BoxShadow(color: VColor.accentGreenGlow, blurRadius: 18, spreadRadius: 1)],
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
