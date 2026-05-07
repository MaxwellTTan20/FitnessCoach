import 'package:flutter/material.dart';
import 'record_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFEAF2FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F4C81), Color(0xFF5B7FA3), Color(0xFFF4F7FB)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                          Text(
                            'Lift & Flow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Train with confident motion.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 255, 255, 0.9),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromRGBO(0, 0, 0, 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bar_chart, color: Color(0xFF0F4C81), size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Strength Focus',
                            style: TextStyle(
                              color: Color(0xFF0F4C81),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aesthetically designed to keep your lifts on track. Tap the camera to record and review your form in real time.',
                        style: TextStyle(
                          color: Color(0xFF526A86),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: const [
                          _FeatureBadge(icon: Icons.sports_martial_arts, label: 'Power'),
                          _FeatureBadge(icon: Icons.shield, label: 'Focus'),
                          _FeatureBadge(icon: Icons.flash_on, label: 'Drive'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Today’s warm-up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
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
                    _WorkoutTile(title: 'Squat Mechanics', icon: Icons.fitness_center),
                    _WorkoutTile(title: 'Core Bracing', icon: Icons.shield_moon),
                    _WorkoutTile(title: 'Bar Path', icon: Icons.timeline),
                    _WorkoutTile(title: 'Mobility Flow', icon: Icons.self_improvement),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F4C81),
        elevation: 16,
        splashColor: const Color(0xFF5B7FA3),
        onPressed: () async {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecordPage()),
          );
        },
        child: const Icon(Icons.camera_alt, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        surfaceTintColor: Colors.white,
        color: const Color.fromRGBO(255, 255, 255, 0.95),
        elevation: 14,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => _onItemTapped(0),
              ),
              _NavItem(
                icon: Icons.fitness_center,
                label: 'Workouts',
                selected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              const SizedBox(width: 48),
              _NavItem(
                icon: Icons.show_chart,
                label: 'Stats',
                selected: _selectedIndex == 2,
                onTap: () => _onItemTapped(2),
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Profile',
                selected: _selectedIndex == 3,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0F4C81)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2B4A68),
              fontWeight: FontWeight.w600,
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

  const _WorkoutTile({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xB3FFFFFF), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F4C81),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          // Flexible(
          //   child: Text(
          //     title,
          //     style: const TextStyle(
          //       color: Color(0xFF1F3B57),
          //       fontSize: 16,
          //       fontWeight: FontWeight.w700,
          //     ),
          //   ),
          // ),
          //const Spacer(),
          // const Text(
          //   'Tap to explore',
          //   style: TextStyle(
          //     color: Color(0xFF6D8196),
          //     fontSize: 12,
          //   ),
          // ),
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
          Icon(icon, color: selected ? const Color(0xFF0F4C81) : Colors.grey.shade500),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF0F4C81) : Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
