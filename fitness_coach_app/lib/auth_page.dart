import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';

import 'auth_config.dart';
import 'movement_lab_theme.dart';
import 'user_profile.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthPage({super.key, required this.onAuthenticated});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _auth0 = Auth0(kAuth0Domain, kAuth0ClientId);
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credentials = await _auth0
          .webAuthentication(scheme: 'com.maxwelltan.fitnessCoachApp')
          .login(parameters: {'connection': 'google-oauth2'});
      final profile = AppProfile.instance;
      await profile.load(); // load cached prefs (name, avatar, etc.) first
      profile.isGuest =
          false; // then set auth data so load() doesn't overwrite it
      profile.auth0UserId = credentials.user.sub;
      profile.email = credentials.user.email;
      if (credentials.user.name != null) profile.name = credentials.user.name!;
      await profile.save(); // persist auth0UserId + isGuest to prefs
      await profile.loadFromFirestore(); // overlay with cloud data
      widget.onAuthenticated();
    } catch (e) {
      setState(() => _error = 'Sign-in failed. Please try again.');
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
