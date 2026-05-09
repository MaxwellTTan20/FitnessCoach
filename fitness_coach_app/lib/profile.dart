import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';

import 'config/auth_config.dart';
import 'auth_page.dart';
import 'user_profile.dart';

const List<String> _profileImages = [
  'lib/images/profile_pictures/panda.jpg',
  'lib/images/profile_pictures/perry.png',
  'lib/images/profile_pictures/bigben.jpg'
];

class ProfilePage extends StatefulWidget {
  final VoidCallback? onSignOut;
  const ProfilePage({super.key, this.onSignOut});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profile = AppProfile.instance;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late int _avatarIndex;
  late String _experience;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _profile.name);
    _usernameCtrl = TextEditingController(text: _profile.username);
    _avatarIndex = _profile.avatarIndex.clamp(0, _profileImages.length - 1);
    _experience = _profile.experience;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    _profile.name = _nameCtrl.text.trim();
    _profile.username = _usernameCtrl.text.trim();
    _profile.avatarIndex = _avatarIndex;
    _profile.experience = _experience;
    await _profile.save();
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _goToSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthPage(
          onAuthenticated: () {
            Navigator.of(context).pop();
            _nameCtrl.text = _profile.name;
            _usernameCtrl.text = _profile.username;
            setState(() {
              _avatarIndex = _profile.avatarIndex.clamp(0, _profileImages.length - 1);
              _experience = _profile.experience;
            });
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await Auth0(kAuth0Domain, kAuth0ClientId)
          .webAuthentication(scheme: kAuth0Scheme)
          .logout();
    } catch (_) {}
    await _profile.clear();
    _nameCtrl.text = '';
    _usernameCtrl.text = '';
    setState(() {
      _avatarIndex = 0;
      _experience = 'Beginner';
    });
    widget.onSignOut?.call();
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162033),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Profile Picture',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                children: List.generate(_profileImages.length, (i) {
                  final selected = _avatarIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _avatarIndex = i);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.cyanAccent : Colors.white30,
                            width: selected ? 3 : 1.5,
                          ),
                          boxShadow: selected
                              ? [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.3), blurRadius: 12)]
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundImage: AssetImage(_profileImages[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    final bottomPad = MediaQuery.of(context).padding.bottom + 90;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1E31),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_profile.isGuest)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                  : const Text('Save', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isSmall ? 16 : 24,
          isSmall ? 16 : 24,
          isSmall ? 16 : 24,
          bottomPad,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Guest banner ───────────────────────────────────────────
            if (_profile.isGuest)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guest mode — changes are not saved between sessions.',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: isSmall ? 12 : 13),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Avatar + name/username row ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white12,
                        backgroundImage: AssetImage(_profileImages[_avatarIndex]),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.cyanAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 13, color: Color(0xFF0E1E31)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(_nameCtrl, 'Your full name'),
                      const SizedBox(height: 12),
                      _field(_usernameCtrl, '@username'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Experience ────────────────────────────────────────────
            _sectionLabel('Experience Level'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppProfile.experiences.map((level) {
                final selected = _experience == level;
                return GestureDetector(
                  onTap: () => setState(() => _experience = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.cyanAccent.withValues(alpha: 0.15) : Colors.white10,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? Colors.cyanAccent : Colors.white24,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(
                        color: selected ? Colors.cyanAccent : Colors.white70,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            // ── Sign out / sign in ─────────────────────────────────────
            if (_profile.isGuest)
              _ActionButton(
                label: 'Sign in to save progress',
                icon: Icons.login,
                color: Colors.cyanAccent,
                onTap: _goToSignIn,
              )
            else
              _ActionButton(
                label: 'Sign out',
                icon: Icons.logout,
                color: Colors.redAccent,
                onTap: _signOut,
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      );

  Widget _field(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.white10,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
