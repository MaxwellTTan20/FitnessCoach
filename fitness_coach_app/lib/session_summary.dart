import 'dart:math' as math;

import 'package:flutter/material.dart';

class SessionSummaryPage extends StatelessWidget {
  final String exercise;
  final int correctCount;
  final int incorrectCount;

  const SessionSummaryPage({
    super.key,
    required this.exercise,
    required this.correctCount,
    required this.incorrectCount,
  });

  int get _total => correctCount + incorrectCount;
  double get _accuracy => _total > 0 ? correctCount / _total : 0.0;

  Color get _accuracyColor {
    if (_accuracy >= 0.8) return const Color(0xFF43A047);
    if (_accuracy >= 0.5) return const Color(0xFFFFC107);
    return const Color(0xFFE53935);
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Session Summary',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── Exercise badge ─────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4C81).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center,
                        color: Color(0xFF1E88E5), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      exercise,
                      style: const TextStyle(
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

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
                              color: Colors.white54,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Stat cards ─────────────────────────────────────────────
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
                      value: '$correctCount',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF43A047),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Incorrect',
                      value: '$incorrectCount',
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // ── Done button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
