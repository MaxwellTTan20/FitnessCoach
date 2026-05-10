import 'package:flutter/material.dart';

import 'movement_lab_theme.dart';
import 'record_page.dart';
import 'user_profile.dart';
import 'workout_state.dart';

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

List<WorkoutGoal> _parseGoals(List<String> sets) {
  final goals = <WorkoutGoal>[];
  for (final set in sets) {
    final parts = set.split('×');
    if (parts.length < 2) continue;
    final setCount = int.tryParse(parts[0].trim()) ?? 0;
    final detailParts = parts[1].trim().split(RegExp(r'\s+'));
    if (detailParts.length < 2) continue;
    final repCount = int.tryParse(detailParts[0]) ?? 0;
    final exercise = detailParts.sublist(1).join(' ');
    if (setCount > 0 && repCount > 0 && exercise.isNotEmpty) {
      goals.add(
        WorkoutGoal(exercise: exercise, targetReps: setCount * repCount),
      );
    }
  }
  return goals;
}

int _firstTrackableExerciseIndex(List<WorkoutGoal> goals) {
  const trackableExercises = {'Squat', 'Push-up'};
  final target = goals
      .map((goal) => goal.exercise)
      .where(trackableExercises.contains)
      .firstOrNull;
  if (target == null) return 0;
  final index = AppProfile.exercises.indexOf(target);
  return index >= 0 ? index : 0;
}

const _singles = [
  _SingleExercise(
    'Just Squat',
    Icons.airline_seat_legroom_extra,
    MovementLabColors.trackTeal,
  ),
  _SingleExercise(
    'Just Bench',
    Icons.fitness_center,
    MovementLabColors.correction,
  ),
  _SingleExercise('Just Deadlift', Icons.hardware, MovementLabColors.graphite),
  _SingleExercise(
    'Just Push-up',
    Icons.sports_martial_arts,
    MovementLabColors.correct,
  ),
];

const _plans = [
  _WorkoutPlan(
    name: 'Push Day',
    icon: Icons.fitness_center,
    color: MovementLabColors.correction,
    sets: ['4 × 8  Bench', '3 × 15  Push-up'],
    intensity: 3,
    description: 'Classic press session targeting chest and triceps.',
  ),
  _WorkoutPlan(
    name: 'Leg Day',
    icon: Icons.airline_seat_legroom_extra,
    color: MovementLabColors.trackTeal,
    sets: ['4 × 6  Squat', '3 × 5  Deadlift'],
    intensity: 5,
    description: 'Heavy compound lower-body work for maximum strength.',
  ),
  _WorkoutPlan(
    name: 'Strength Endurance',
    icon: Icons.loop,
    color: MovementLabColors.correct,
    sets: ['4 × 15  Squat', '4 × 20  Push-up'],
    intensity: 2,
    description: 'High-rep conditioning to build work capacity.',
  ),
  _WorkoutPlan(
    name: 'Upper Power',
    icon: Icons.bolt,
    color: MovementLabColors.tempo,
    sets: ['5 × 5  Bench', '3 × 5  Deadlift'],
    intensity: 4,
    description: 'Heavy pressing paired with a posterior chain pull.',
  ),
  _WorkoutPlan(
    name: 'Power Trio',
    icon: Icons.emoji_events,
    color: MovementLabColors.graphite,
    sets: ['3 × 5  Squat', '3 × 5  Bench', '3 × 5  Deadlift'],
    intensity: 5,
    description: 'The classic powerlifting three. Pure strength focus.',
  ),
  _WorkoutPlan(
    name: 'Full Body',
    icon: Icons.all_inclusive,
    color: MovementLabColors.trackTeal,
    sets: [
      '3 × 8  Squat',
      '4 × 8  Bench',
      '3 × 5  Deadlift',
      '3 × 15  Push-up',
    ],
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
      color: MovementLabColors.porcelain,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          LabLabel('Training menu'),
                          SizedBox(height: 8),
                          Text(
                            'Workouts',
                            style: TextStyle(
                              color: MovementLabColors.ink,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose a session to measure',
                            style: TextStyle(
                              color: MovementLabColors.muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: MovementLabColors.white,
                        border: Border.all(color: MovementLabColors.graphite),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(
                        Icons.fitness_center,
                        color: MovementLabColors.graphite,
                        size: 24,
                      ),
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
                    color: MovementLabColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
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
                  children: _singles
                      .asMap()
                      .entries
                      .map(
                        (e) => _SingleCard(
                          exercise: e.value,
                          onTap: () {
                            WorkoutState.instance.activeWorkout = null;
                            AppProfile.instance.setExercise(e.key).ignore();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RecordPage(),
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
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
                    color: MovementLabColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
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
          color: MovementLabColors.white,
          border: Border.all(
            color: exercise.color.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: exercise.color.withValues(alpha: 0.2),
                border: Border.all(
                  color: exercise.color.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(exercise.icon, color: exercise.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                exercise.name,
                style: const TextStyle(
                  color: MovementLabColors.graphite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
      onTap: () {
        final goals = _parseGoals(plan.sets);
        WorkoutState.instance.activeWorkout = ActiveWorkout(
          name: plan.name,
          goals: goals,
        );
        AppProfile.instance
            .setExercise(_firstTrackableExerciseIndex(goals))
            .ignore();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RecordPage()));
      },
      child: Container(
        decoration: BoxDecoration(
          color: MovementLabColors.white,
          border: Border.all(
            color: plan.color.withValues(alpha: 0.3),
            width: 1.2,
          ),
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
                border: Border.all(color: plan.color.withValues(alpha: 0.28)),
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
                            color: MovementLabColors.graphite,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
                      color: MovementLabColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
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
    if (level <= 2) return MovementLabColors.correct;
    if (level == 3) return MovementLabColors.tempo;
    if (level == 4) return MovementLabColors.correction;
    return MovementLabColors.correction;
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
            color: i < level ? color : MovementLabColors.line,
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
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
