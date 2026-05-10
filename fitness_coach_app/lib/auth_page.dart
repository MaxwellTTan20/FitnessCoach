import 'package:flutter/material.dart';
import 'auth_service.dart';
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

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = await AppAuthService.instance.signInWithGoogle();
      final profile = AppProfile.instance;
      await profile.load();              // load cached prefs (name, avatar, etc.) first
      profile.isGuest = false;           // then set auth data so load() doesn't overwrite it
      profile.auth0UserId = session.userId;
      profile.email = session.email;
      if (session.name != null) profile.name = session.name!;
      await profile.save();              // persist auth0UserId + isGuest to prefs
      await profile.loadFromFirestore(); // overlay with cloud data
      widget.onAuthenticated();
    } catch (e) {
      debugPrint('[Auth] Error: $e');
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1628), Color(0xFF0F2340), Color(0xFF0E1E31)],
          ),
        ),
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
                    color: Colors.cyanAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.cyanAccent, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Capy Coach',
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'AI-powered form coaching',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const Spacer(flex: 2),
                // ── Buttons ───────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                  icon: const Icon(Icons.person_outline, color: Colors.white70, size: 20),
                  label: 'Continue as Guest',
                  primary: false,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Guest sessions are not saved between app launches.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 12),
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
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      alignment: Alignment.center,
      child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w800, fontSize: 13)),
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
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: primary ? null : Border.all(color: Colors.white24),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: primary ? const Color(0xFF0A1628) : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
