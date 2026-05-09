import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

import 'auth_page.dart';
import 'movement_lab_theme.dart';
import 'profile.dart';
import 'record_page.dart';
import 'stats.dart';
import 'user_profile.dart';
import 'workouts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppProfile.instance.load();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness Coach',
      theme: buildMovementLabTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // Show auth page only if the profile has never been set up
  // (guest users who return still go straight to home).
  bool _showAuth = !AppProfile.instance.hasEverLaunched;

  @override
  Widget build(BuildContext context) {
    if (_showAuth) {
      return AuthPage(
        onAuthenticated: () {
          AppProfile.instance.markLaunched();
          setState(() => _showAuth = false);
        },
      );
    }
    return const HomePage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      backgroundColor: MovementLabColors.porcelain,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(screenWidth: screenWidth),
          const WorkoutsPage(),
          const StatsPage(),
          ProfilePage(onSignOut: () => setState(() => _selectedIndex = 0)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RecordPage())),
        child: const Icon(Icons.camera_alt_outlined, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(),
          RoundedRectangleBorder(),
        ),
        notchMargin: 6,
        color: MovementLabColors.white,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _NavItem(
                icon: Icons.fitness_center,
                label: 'Workouts',
                selected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              const SizedBox(width: 48),
              _NavItem(
                icon: Icons.show_chart,
                label: 'Stats',
                selected: _selectedIndex == 2,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Profile',
                selected: _selectedIndex == 3,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home tab content ──────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final double screenWidth;
  const _HomeTab({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MovementLabColors.porcelain,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          LabLabel('Movement Lab'),
                          SizedBox(height: 10),
                          Text(
                            'Lift & Flow',
                            style: TextStyle(
                              color: MovementLabColors.ink,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Train with measured motion.',
                            style: TextStyle(
                              color: MovementLabColors.muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: MovementLabColors.white,
                        border: Border.all(
                          color: MovementLabColors.graphite,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.science_outlined,
                        color: MovementLabColors.graphite,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                LabPanel(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            color: MovementLabColors.trackTeal,
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Readiness instrument',
                            style: TextStyle(
                              color: MovementLabColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap the camera to measure live movement, track joint angles, and receive short form cues while you train.',
                        style: TextStyle(
                          color: MovementLabColors.muted,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const CalibrationRule(),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: const [
                          _FeatureBadge(icon: Icons.sensors, label: 'Track'),
                          _FeatureBadge(
                            icon: Icons.check_circle_outline,
                            label: 'Correct',
                          ),
                          _FeatureBadge(
                            icon: Icons.timer_outlined,
                            label: 'Tempo',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  "Today's movement plan",
                  style: TextStyle(
                    color: MovementLabColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: screenWidth < 360 ? 1 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: screenWidth < 360 ? 3 / 1 : 4 / 3,
                  children: const [
                    _WorkoutTile(
                      title: 'Squat',
                      description: 'Depth and knee path',
                      icon: Icons.airline_seat_legroom_extra,
                    ),
                    _WorkoutTile(
                      title: 'Bench',
                      description: 'Coming soon',
                      icon: Icons.fitness_center,
                    ),
                    _WorkoutTile(
                      title: 'Deadlift',
                      description: 'Coming soon',
                      icon: Icons.timeline,
                    ),
                    _WorkoutTile(
                      title: 'Push-up',
                      description: 'Body line and elbow angle',
                      icon: Icons.self_improvement,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MovementLabColors.paper,
        border: Border.all(color: MovementLabColors.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: MovementLabColors.trackTeal),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: MovementLabColors.graphite,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  const _WorkoutTile({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MovementLabColors.white,
        border: Border.all(color: MovementLabColors.lineStrong, width: 1.2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: MovementLabColors.tealSoft,
                  border: Border.all(color: MovementLabColors.trackTeal),
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: MovementLabColors.trackTeal, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: MovementLabColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            description,
            style: const TextStyle(
              color: MovementLabColors.muted,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected
                ? MovementLabColors.graphite
                : MovementLabColors.muted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? MovementLabColors.graphite
                  : MovementLabColors.muted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
