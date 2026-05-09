import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'movement_lab_theme.dart';
import 'user_profile.dart';

class SessionSummaryPage extends StatefulWidget {
  // Key: exercise name, Value: {correct, incorrect}
  final Map<String, Map<String, int>> exerciseStats;

  const SessionSummaryPage({super.key, required this.exerciseStats});

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  int get _totalCorrect =>
      widget.exerciseStats.values.fold(0, (s, m) => s + (m['correct'] ?? 0));
  int get _totalIncorrect =>
      widget.exerciseStats.values.fold(0, (s, m) => s + (m['incorrect'] ?? 0));
  int get _total => _totalCorrect + _totalIncorrect;
  double get _accuracy => _total > 0 ? _totalCorrect / _total : 0.0;

  Color get _accuracyColor {
    if (_accuracy >= 0.8) return MovementLabColors.correct;
    if (_accuracy >= 0.5) return MovementLabColors.tempo;
    return MovementLabColors.correction;
  }

  Future<void> _saveSession() async {
    final profile = AppProfile.instance;
    debugPrint(
      '[Session] userId=${profile.auth0UserId}, total=$_total, isGuest=${profile.isGuest}',
    );
    if ((profile.auth0UserId ?? '').isEmpty || _total == 0) {
      debugPrint('[Session] Save skipped — no userId or zero reps');
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
      backgroundColor: MovementLabColors.porcelain,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saveAndPop,
        ),
        title: const Text(
          'Session Summary',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              const LabLabel('Movement report'),
              const SizedBox(height: 14),

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
                          style: TextStyle(
                            color: MovementLabColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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
                      color: MovementLabColors.graphite,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Correct',
                      value: '$_totalCorrect',
                      icon: Icons.check_circle_outline,
                      color: MovementLabColors.correct,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Incorrect',
                      value: '$_totalIncorrect',
                      icon: Icons.cancel_outlined,
                      color: MovementLabColors.correction,
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
                      color: MovementLabColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
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
                    backgroundColor: MovementLabColors.graphite,
                    foregroundColor: MovementLabColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(),
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
      accuracyColor = MovementLabColors.correct;
    } else if (accuracy >= 0.5) {
      accuracyColor = MovementLabColors.tempo;
    } else {
      accuracyColor = MovementLabColors.correction;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MovementLabColors.white,
        border: Border.all(color: MovementLabColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.fitness_center,
            color: MovementLabColors.trackTeal,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              exercise,
              style: const TextStyle(
                color: MovementLabColors.graphite,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            '$total reps',
            style: const TextStyle(
              color: MovementLabColors.muted,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '✓ $correct',
            style: const TextStyle(
              color: MovementLabColors.correct,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '✗ $incorrect',
            style: const TextStyle(
              color: MovementLabColors.correction,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
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
        color: MovementLabColors.white,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: MovementLabColors.muted,
              fontSize: 11,
            ),
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
        ..color = MovementLabColors.line
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
