import 'package:flutter/material.dart';

import 'record_page.dart';
import 'user_profile.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _SingleExercise {
  final String name;
  final IconData icon;
  final Color color;
  const _SingleExercise(this.name, this.icon, this.color);
}

class _WorkoutPlan {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> sets;
  final int intensity; // 1–5
  final String description;
  const _WorkoutPlan({
    required this.name,
    required this.icon,
    required this.color,
    required this.sets,
    required this.intensity,
    required this.description,
  });
}

const _singles = [
  _SingleExercise('Just Squat',    Icons.airline_seat_legroom_extra, Color(0xFF1565C0)),
  _SingleExercise('Just Bench',    Icons.fitness_center,              Color(0xFFC62828)),
  _SingleExercise('Just Deadlift', Icons.hardware,                    Color(0xFF37474F)),
  _SingleExercise('Just Push-up',  Icons.sports_martial_arts,         Color(0xFF2E7D32)),
];

const _plans = [
  _WorkoutPlan(
    name: 'Push Day',
    icon: Icons.fitness_center,
    color: Color(0xFFC62828),
    sets: ['4 × 8  Bench', '3 × 15  Push-up'],
    intensity: 3,
    description: 'Classic press session targeting chest and triceps.',
  ),
  _WorkoutPlan(
    name: 'Leg Day',
    icon: Icons.airline_seat_legroom_extra,
    color: Color(0xFF1565C0),
    sets: ['4 × 6  Squat', '3 × 5  Deadlift'],
    intensity: 5,
    description: 'Heavy compound lower-body work for maximum strength.',
  ),
  _WorkoutPlan(
    name: 'Strength Endurance',
    icon: Icons.loop,
    color: Color(0xFF00695C),
    sets: ['4 × 15  Squat', '4 × 20  Push-up'],
    intensity: 2,
    description: 'High-rep conditioning to build work capacity.',
  ),
  _WorkoutPlan(
    name: 'Upper Power',
    icon: Icons.bolt,
    color: Color(0xFFF57F17),
    sets: ['5 × 5  Bench', '3 × 5  Deadlift'],
    intensity: 4,
    description: 'Heavy pressing paired with a posterior chain pull.',
  ),
  _WorkoutPlan(
    name: 'Power Trio',
    icon: Icons.emoji_events,
    color: Color(0xFF6A1B9A),
    sets: ['3 × 5  Squat', '3 × 5  Bench', '3 × 5  Deadlift'],
    intensity: 5,
    description: 'The classic powerlifting three. Pure strength focus.',
  ),
  _WorkoutPlan(
    name: 'Full Body',
    icon: Icons.all_inclusive,
    color: Color(0xFF0F4C81),
    sets: ['3 × 8  Squat', '4 × 8  Bench', '3 × 5  Deadlift', '3 × 15  Push-up'],
    intensity: 4,
    description: 'Every major compound movement in one session.',
  ),
];

// ── Page ─────────────────────────────────────────────────────────────────────

class WorkoutsPage extends StatelessWidget {
  const WorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 90;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F4C81), Color(0xFF0E1E31), Color(0xFF0E1E31)],
          stops: [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Workouts',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose a session to begin',
                            style: TextStyle(color: Colors.white60, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.fitness_center,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick singles ────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Text(
                  'QUICK SINGLES',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GridView.count(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.8,
                  children: _singles.asMap().entries.map((e) => _SingleCard(
                    exercise: e.value,
                    onTap: () {
                      AppProfile.instance.setExercise(e.key).ignore();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RecordPage()),
                      );
                    },
                  )).toList(),
                ),
              ),
            ),

            // ── Workout programs ─────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 36, 20, 0),
                child: Text(
                  'WORKOUT PROGRAMS',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(plan: _plans[i]),
                  ),
                  childCount: _plans.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single-exercise card ──────────────────────────────────────────────────────

class _SingleCard extends StatelessWidget {
  final _SingleExercise exercise;
  final VoidCallback onTap;
  const _SingleCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: exercise.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: exercise.color.withValues(alpha: 0.4), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: exercise.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(exercise.icon, color: exercise.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                exercise.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Workout-plan card ─────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _WorkoutPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF162033),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: plan.color.withValues(alpha: 0.3), width: 1.2),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: plan.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(plan.icon, color: plan.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      _IntensityBar(level: plan.intensity),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: plan.sets
                        .map((s) => _SetTag(label: s, color: plan.color))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    plan.description,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Intensity bar ─────────────────────────────────────────────────────────────

class _IntensityBar extends StatelessWidget {
  final int level; // 1–5
  const _IntensityBar({required this.level});

  Color _barColor() {
    if (level <= 2) return const Color(0xFF4CAF50);
    if (level == 3) return const Color(0xFFFFC107);
    if (level == 4) return const Color(0xFFFF7043);
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    final color = _barColor();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Container(
          width: 7,
          height: 12,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: i < level ? color : Colors.white12,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Set tag ───────────────────────────────────────────────────────────────────

class _SetTag extends StatelessWidget {
  final String label;
  final Color color;
  const _SetTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
