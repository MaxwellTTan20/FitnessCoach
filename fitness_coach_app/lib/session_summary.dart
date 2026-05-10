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

class _SessionSummaryPageState extends State<SessionSummaryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;

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

  String get _bannerTitle {
    if (_total == 0) return 'Session ready';
    if (_accuracy >= 0.8) return 'Clean movement logged';
    if (_accuracy >= 0.5) return 'Strong work logged';
    return 'Baseline captured';
  }

  String get _bannerMessage {
    if (_total == 0) return 'Start a measured set to build your report.';
    if (_accuracy >= 0.8) return 'Your form stayed sharp. Keep this rhythm.';
    if (_accuracy >= 0.5) {
      return 'Progress is on the board. Refine the next set.';
    }
    return 'Data captured. The next set gets more precise.';
  }

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
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
              AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, _) {
                  return _CelebrationBanner(
                    progress: _celebrationController.value,
                    color: _accuracyColor,
                    title: _bannerTitle,
                    message: _bannerMessage,
                    total: _total,
                  );
                },
              ),
              const SizedBox(height: 22),

              // ── Accuracy arc ───────────────────────────────────────────
              AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, _) {
                  final arcProgress = Curves.easeOutCubic.transform(
                    (_celebrationController.value / 0.78).clamp(0.0, 1.0),
                  );
                  return Transform.scale(
                    scale: 0.94 + (arcProgress * 0.06),
                    child: Opacity(
                      opacity: arcProgress,
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                          painter: _SummaryArcPainter(
                            value: _accuracy * arcProgress,
                            color: _accuracyColor,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(_accuracy * 100 * arcProgress).round()}%',
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
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Overall stat cards ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _AnimatedReportItem(
                      controller: _celebrationController,
                      delay: 0.20,
                      child: _StatCard(
                        label: 'Total Reps',
                        value: '$_total',
                        icon: Icons.repeat,
                        color: MovementLabColors.graphite,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnimatedReportItem(
                      controller: _celebrationController,
                      delay: 0.30,
                      child: _StatCard(
                        label: 'Correct',
                        value: '$_totalCorrect',
                        icon: Icons.check_circle_outline,
                        color: MovementLabColors.correct,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AnimatedReportItem(
                      controller: _celebrationController,
                      delay: 0.40,
                      child: _StatCard(
                        label: 'Incorrect',
                        value: '$_totalIncorrect',
                        icon: Icons.cancel_outlined,
                        color: MovementLabColors.correction,
                      ),
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
                  (e) => _AnimatedReportItem(
                    controller: _celebrationController,
                    delay: 0.52,
                    child: _ExerciseRow(
                      exercise: e.key,
                      correct: e.value['correct'] ?? 0,
                      incorrect: e.value['incorrect'] ?? 0,
                    ),
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

// ── Celebration banner ───────────────────────────────────────────────────────

class _CelebrationBanner extends StatelessWidget {
  final double progress;
  final Color color;
  final String title;
  final String message;
  final int total;

  const _CelebrationBanner({
    required this.progress,
    required this.color,
    required this.title,
    required this.message,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MovementLabColors.white,
            border: Border.all(color: color, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CelebrationPulsePainter(
                    progress: progress,
                    color: color,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      border: Border.all(color: color),
                    ),
                    child: Icon(
                      total > 0 ? Icons.emoji_events_outlined : Icons.sensors,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LabLabel('Calibration complete'),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: const TextStyle(
                            color: MovementLabColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message,
                          style: const TextStyle(
                            color: MovementLabColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelebrationPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CelebrationPulsePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1.2;
    final sweep = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final centerY = size.height / 2;

    for (var i = 0; i < 9; i++) {
      final x = size.width - 18 - (i * 18.0);
      final height =
          (10 + (math.sin((progress * math.pi * 2) + i) * 6).abs()) * sweep;
      canvas.drawLine(
        Offset(x, centerY - height),
        Offset(x, centerY + height),
        paint,
      );
    }

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.12 * sweep)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      Offset(size.width - 42, centerY),
      20 + (20 * sweep),
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CelebrationPulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _AnimatedReportItem extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Widget child;

  const _AnimatedReportItem({
    required this.controller,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final raw = ((controller.value - delay) / 0.38).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(raw);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 16),
            child: child,
          ),
        );
      },
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
