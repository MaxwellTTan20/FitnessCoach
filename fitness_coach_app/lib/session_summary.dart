import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'user_profile.dart';

class SessionSummaryPage extends StatefulWidget {
  // Key: exercise name, Value: {correct, incorrect}
  final Map<String, Map<String, int>> exerciseStats;

  const SessionSummaryPage({super.key, required this.exerciseStats});

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  int get _totalCorrect => widget.exerciseStats.values
      .fold(0, (s, m) => s + (m['correct'] ?? 0));
  int get _totalIncorrect => widget.exerciseStats.values
      .fold(0, (s, m) => s + (m['incorrect'] ?? 0));
  int get _total => _totalCorrect + _totalIncorrect;
  double get _accuracy => _total > 0 ? _totalCorrect / _total : 0.0;

  Color get _accuracyColor {
    if (_accuracy >= 0.8) return const Color(0xFF43A047);
    if (_accuracy >= 0.5) return const Color(0xFFFFC107);
    return const Color(0xFFE53935);
  }

  Future<void> _saveSession() async {
    final profile = AppProfile.instance;
    debugPrint('[Session] userId=${profile.auth0UserId}, total=$_total, isGuest=${profile.isGuest}');

    // Award grass for everyone (guests included) based on lifetime milestones.
    if (_totalCorrect > 0) {
      final prevMilestone = profile.lifetimeCorrectReps ~/ 10;
      profile.lifetimeCorrectReps += _totalCorrect;
      final newMilestone = profile.lifetimeCorrectReps ~/ 10;
      final grassEarned = newMilestone - prevMilestone;
      debugPrint('[Session] lifetimeCorrectReps=${profile.lifetimeCorrectReps}, grassEarned=$grassEarned');
      if (grassEarned > 0) {
        profile.grassBalance += grassEarned;
        await profile.saveCapybara();
      }
    }

    // Firestore save — signed-in users only.
    if ((profile.auth0UserId ?? '').isEmpty || _total == 0) {
      debugPrint('[Session] Firestore save skipped — no userId or zero reps');
      return;
    }
    try {
      final lifts = widget.exerciseStats.entries.map((e) {
        final correct = e.value['correct'] ?? 0;
        final incorrect = e.value['incorrect'] ?? 0;
        final total = correct + incorrect;
        return {
          'exercise': e.key,
          'correctCount': correct,
          'incorrectCount': incorrect,
          'totalReps': total,
          'accuracy': total > 0 ? correct / total : 0.0,
        };
      }).toList();

      final ref = await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.auth0UserId)
          .collection('sessions')
          .add({
        'lifts': lifts,
        'totalReps': _total,
        'accuracy': _accuracy,
        'completedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[Session] Saved at sessions/${ref.id}');
    } catch (e) {
      debugPrint('[Session] Failed to save: $e');
    }
  }

  void _saveAndPop() {
    _saveSession();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1E31),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _saveAndPop,
        ),
        title: const Text(
          'Session Summary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Accuracy arc ───────────────────────────────────────────
              SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  painter: _SummaryArcPainter(
                    value: _accuracy,
                    color: _accuracyColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_accuracy * 100).round()}%',
                          style: TextStyle(
                            color: _accuracyColor,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Accuracy',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Overall stat cards ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total Reps',
                      value: '$_total',
                      icon: Icons.repeat,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Correct',
                      value: '$_totalCorrect',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF43A047),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Incorrect',
                      value: '$_totalIncorrect',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),

              // ── Per-exercise breakdown ─────────────────────────────────
              if (widget.exerciseStats.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'By Exercise',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...widget.exerciseStats.entries.map(
                  (e) => _ExerciseRow(
                    exercise: e.key,
                    correct: e.value['correct'] ?? 0,
                    incorrect: e.value['incorrect'] ?? 0,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Done button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAndPop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Per-exercise row ──────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  final String exercise;
  final int correct;
  final int incorrect;

  const _ExerciseRow({
    required this.exercise,
    required this.correct,
    required this.incorrect,
  });

  @override
  Widget build(BuildContext context) {
    final total = correct + incorrect;
    final accuracy = total > 0 ? correct / total : 0.0;
    Color accuracyColor;
    if (accuracy >= 0.8) {
      accuracyColor = const Color(0xFF43A047);
    } else if (accuracy >= 0.5) {
      accuracyColor = const Color(0xFFFFC107);
    } else {
      accuracyColor = const Color(0xFFE53935);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center, color: Color(0xFF1E88E5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '$total reps',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(
            '✓ $correct',
            style: const TextStyle(
                color: Color(0xFF43A047),
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            '✗ $incorrect',
            style: const TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
          const SizedBox(width: 12),
          Text(
            '${(accuracy * 100).round()}%',
            style: TextStyle(
              color: accuracyColor,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _SummaryArcPainter extends CustomPainter {
  final double value;
  final Color color;
  _SummaryArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 10;
    const strokeW = 12.0;

    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        2 * math.pi * value,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SummaryArcPainter old) => old.value != value;
}
