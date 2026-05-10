import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

import 'auth_page.dart';
import 'capybara_feeder.dart';
import 'profile.dart';
import 'record_page.dart';
import 'stats.dart';
import 'user_profile.dart';
import 'workout_state.dart';
import 'workouts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppProfile.instance.load();
  if (AppProfile.instance.auth0UserId != null) {
    await AppProfile.instance.loadFromFirestore();
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fitness Coach',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
        useMaterial3: true,
      ),
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
      backgroundColor: const Color(0xFFEAF2FA),
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
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F4C81),
        elevation: 16,
        splashColor: const Color(0xFF5B7FA3),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecordPage()),
        ).then((_) => setState(() {})),
        child: const Icon(Icons.camera_alt, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color.fromRGBO(255, 255, 255, 0.95),
        elevation: 14,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home, label: 'Home', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
              _NavItem(icon: Icons.fitness_center, label: 'Workouts', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
              const SizedBox(width: 48),
              _NavItem(icon: Icons.show_chart, label: 'Stats', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
              _NavItem(icon: Icons.person, label: 'Profile', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F4C81), Color(0xFF5B7FA3), Color(0xFFF4F7FB)],
        ),
      ),
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
                          Text('Lift & Flow', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                          SizedBox(height: 8),
                          Text('Train with confident motion.', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset('lib/images/icons/favicon.png', width: 36, height: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const CapybaraCard(),
                const SizedBox(height: 26),
                const Text("Today's warm-up", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Builder(builder: (ctx) {
                  void launchWarmup(String exercise, int exerciseIdx) {
                    WorkoutState.instance.activeWorkout = ActiveWorkout(
                      name: '$exercise Warm-up',
                      goals: [WorkoutGoal(exercise: exercise, targetReps: 3)],
                    );
                    AppProfile.instance.setExercise(exerciseIdx).ignore();
                    Navigator.of(ctx).push(
                      MaterialPageRoute(builder: (_) => const RecordPage()),
                    );
                  }
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: screenWidth < 360 ? 1 : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: screenWidth < 360 ? 3 / 1 : 4 / 3,
                    children: [
                      _WorkoutTile(title: 'Squat',    description: 'Warm-up: 1×3', icon: Icons.fitness_center,    onTap: () => launchWarmup('Squat',   0)),
                      _WorkoutTile(title: 'Bench',    description: 'Warm-up: 1×3', icon: Icons.shield_moon,       onTap: () => launchWarmup('Bench',   1)),
                      _WorkoutTile(title: 'Deadlift', description: 'Warm-up: 1×3', icon: Icons.timeline,          onTap: () => launchWarmup('Deadlift',2)),
                      _WorkoutTile(title: 'Push-ups', description: 'Warm-up: 1×3', icon: Icons.self_improvement,  onTap: () => launchWarmup('Push-up', 3)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ── Shared widgets ────────────────────────────────────────────────────────────

class _WorkoutTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback? onTap;
  const _WorkoutTile({required this.title, required this.description, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xB3FFFFFF), width: 1.2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0F4C81), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A3A5C),
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
              color: Color(0xFF526A86),
              fontSize: 15,
            ),
          ),
        ],
      ),
    ),  // Container
    );  // GestureDetector
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? const Color(0xFF0F4C81) : Colors.grey.shade500),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selected ? const Color(0xFF0F4C81) : Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }
}
