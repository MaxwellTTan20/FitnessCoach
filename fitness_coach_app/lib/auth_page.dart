import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_session.dart';
import 'movement_lab_theme.dart';
import 'user_profile.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthPage({super.key, required this.onAuthenticated});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _loading = false;
  String? _error;

  Future<void> _applyAuthSession(AuthSession session) async {
    final profile = AppProfile.instance;
    await profile.load();
    profile.isGuest = false;
    profile.auth0UserId = session.userId;
    profile.email = session.email;
    if (session.name != null) profile.name = session.name!;
    await profile.save();
    await profile.loadFromFirestore();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await AppAuthService.instance.signInWithGoogle();
      await _applyAuthSession(session);
      widget.onAuthenticated();
    } catch (e) {
      debugPrint('[Auth] Sign-in failed: $e');
      setState(() => _error = 'Sign-in failed. Check Auth0 settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueAsGuest() {
    AppProfile.instance.isGuest = true;
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: MovementLabColors.porcelain,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // ── Branding ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MovementLabColors.white,
                    border: Border.all(
                      color: MovementLabColors.graphite,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.science_outlined,
                    color: MovementLabColors.graphite,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Lift & Flow',
                  style: TextStyle(
                    color: MovementLabColors.ink,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Biomechanical form coaching',
                  style: TextStyle(
                    color: MovementLabColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                const CalibrationRule(),
                const Spacer(flex: 2),
                // ── Buttons ───────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MovementLabColors.correctionSoft,
                      border: Border.all(color: MovementLabColors.correction),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: MovementLabColors.correction,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _AuthButton(
                  onTap: _loading ? null : _signInWithGoogle,
                  loading: _loading,
                  icon: _googleIcon(),
                  label: 'Continue with Google',
                  primary: true,
                ),
                const SizedBox(height: 12),
                _AuthButton(
                  onTap: _loading ? null : _continueAsGuest,
                  loading: false,
                  icon: const Icon(
                    Icons.person_outline,
                    color: MovementLabColors.graphite,
                    size: 20,
                  ),
                  label: 'Continue as Guest',
                  primary: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Guest sessions are not saved between app launches.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MovementLabColors.muted,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(color: MovementLabColors.white),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: MovementLabColors.graphite,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final Widget icon;
  final String label;
  final bool primary;

  const _AuthButton({
    required this.onTap,
    required this.loading,
    required this.icon,
    required this.label,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: primary ? MovementLabColors.graphite : MovementLabColors.white,
          border: Border.all(
            color: primary
                ? MovementLabColors.graphite
                : MovementLabColors.lineStrong,
          ),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: primary
                          ? MovementLabColors.white
                          : MovementLabColors.graphite,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
