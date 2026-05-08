import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'user_profile.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _exerciseColors = [
  Color(0xFF1E88E5), // Squat  – blue
  Color(0xFFE53935), // Bench  – red
  Color(0xFF78909C), // Deadlift – blue-grey
  Color(0xFF43A047), // Push-up – green
];

enum _Period { day, week, month, year }

extension _PeriodExt on _Period {
  String get label {
    switch (this) {
      case _Period.day:   return 'Day';
      case _Period.week:  return 'Week';
      case _Period.month: return 'Month';
      case _Period.year:  return 'Year';
    }
  }

  List<String> get xLabels {
    switch (this) {
      case _Period.day:   return ['6am', '9am', '12pm', '3pm', '6pm', '9pm'];
      case _Period.week:  return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case _Period.month: return ['W1', 'W2', 'W3', 'W4'];
      case _Period.year:  return ['Jan', 'Mar', 'May', 'Jul', 'Sep', 'Nov'];
    }
  }
}

// ── Page ─────────────────────────────────────────────────────────────────────

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.week;

  // Placeholder — swap these lists with real data later
  final List<int> _reps = [0, 0, 0, 0];
  final List<double> _accuracy = [0.0, 0.0, 0.0, 0.0];
  // Progression: one list of y-values (0–1) per exercise, matching xLabels length
  List<List<double>> get _progression =>
      List.generate(4, (_) => List.filled(_period.xLabels.length, 0.0));
  final int _calories = 0;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 90;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F4C81), Color(0xFF0E1E31), Color(0xFF0E1E31)],
          stops: [0.0, 0.32, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad),
          physics: const BouncingScrollPhysics(),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildPeriodToggle(),
            const SizedBox(height: 28),
            _label('REPS PER EXERCISE'),
            const SizedBox(height: 12),
            _chartCard(
              height: 190,
              child: CustomPaint(
                painter: _BarChartPainter(
                  values: _reps,
                  labels: AppProfile.exercises,
                  colors: _exerciseColors,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _label('FORM ACCURACY'),
            const SizedBox(height: 12),
            _buildAccuracyGrid(),
            const SizedBox(height: 28),
            _label('ACCURACY PROGRESSION'),
            const SizedBox(height: 12),
            _chartCard(
              height: 210,
              child: CustomPaint(
                painter: _LineChartPainter(
                  series: _progression,
                  xLabels: _period.xLabels,
                  colors: _exerciseColors,
                  exerciseLabels: AppProfile.exercises,
                ),
              ),
            ),
            const SizedBox(height: 28),
            _label('CALORIES BURNED'),
            const SizedBox(height: 12),
            _buildCaloriesCard(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Stats',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Track your progress',
                  style: TextStyle(color: Colors.white60, fontSize: 14)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.show_chart, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  // ── Period toggle ──────────────────────────────────────────────────────────

  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white10, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _Period.values.map((p) {
          final sel = _period == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF0F4C81) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.label,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Accuracy grid (2×2) ───────────────────────────────────────────────────

  Widget _buildAccuracyGrid() {
    return GridView.count(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: List.generate(4, (i) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF162033),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: _ArcPainter(
                    value: _accuracy[i],
                    color: _exerciseColors[i],
                  ),
                  child: Center(
                    child: Text(
                      '${(_accuracy[i] * 100).round()}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppProfile.exercises[i],
                style: TextStyle(
                    color: _exerciseColors[i],
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Calories ───────────────────────────────────────────────────────────────

  Widget _buildCaloriesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_fire_department,
                color: Colors.orange, size: 28),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_calories kcal',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Approximate calories burned',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );

  Widget _chartCard({required double height, required Widget child}) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

// ── Bar chart painter ─────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final List<Color> colors;

  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 22.0;
    const axisW = 32.0;
    const gridLines = 4;

    final chartH = size.height - labelH;
    final chartW = size.width - axisW;
    final maxVal = values.reduce(math.max).clamp(1, 9999);

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white38, fontSize: 10);

    // Horizontal grid lines + Y axis labels
    for (int i = 0; i <= gridLines; i++) {
      final y = chartH * (1 - i / gridLines);
      canvas.drawLine(
          Offset(axisW, y), Offset(size.width, y), gridPaint);
      final label = (maxVal * i ~/ gridLines).toString();
      _drawText(canvas, label, Offset(0, y - 7), textStyle,
          width: axisW - 4, align: TextAlign.right);
    }

    // Bars
    final barGroupW = chartW / values.length;
    const barInset = 8.0;

    for (int i = 0; i < values.length; i++) {
      final barH = values[i] == 0
          ? 3.0
          : (chartH * values[i] / maxVal).clamp(3.0, chartH);
      final left = axisW + i * barGroupW + barInset;
      final right = axisW + (i + 1) * barGroupW - barInset;
      final top = chartH - barH;

      final barPaint = Paint()
        ..color = values[i] == 0
            ? colors[i].withValues(alpha: 0.2)
            : colors[i];

      final rr = RRect.fromLTRBR(
          left, top, right, chartH, const Radius.circular(6));
      canvas.drawRRect(rr, barPaint);

      // X label
      _drawText(
        canvas,
        labels[i],
        Offset(left, chartH + 5),
        TextStyle(
            color: colors[i].withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w600),
        width: right - left,
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.values != values;
}

// ── Line chart painter ────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<List<double>> series; // one list per exercise, values 0–1
  final List<String> xLabels;
  final List<Color> colors;
  final List<String> exerciseLabels;

  _LineChartPainter({
    required this.series,
    required this.xLabels,
    required this.colors,
    required this.exerciseLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const legendH = 24.0;
    const xLabelH = 20.0;
    const axisW = 34.0;
    const gridLines = 4;

    final chartH = size.height - legendH - xLabelH;
    final chartW = size.width - axisW;

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    final axisTextStyle =
        const TextStyle(color: Colors.white38, fontSize: 10);

    // Grid lines + Y labels (0–100%)
    for (int i = 0; i <= gridLines; i++) {
      final y = legendH + chartH * (1 - i / gridLines);
      canvas.drawLine(Offset(axisW, y), Offset(size.width, y), gridPaint);
      _drawText(canvas, '${i * 25}%', Offset(0, y - 7), axisTextStyle,
          width: axisW - 4, align: TextAlign.right);
    }

    // X labels
    final xStep = chartW / (xLabels.length - 1).clamp(1, 9999);
    for (int i = 0; i < xLabels.length; i++) {
      final x = axisW + i * xStep;
      _drawText(
        canvas,
        xLabels[i],
        Offset(x - 16, legendH + chartH + 4),
        axisTextStyle,
        width: 32,
        align: TextAlign.center,
      );
    }

    // Lines
    for (int s = 0; s < series.length; s++) {
      final pts = series[s];
      if (pts.length < 2) continue;
      final linePaint = Paint()
        ..color = colors[s].withValues(alpha: 0.85)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final x = axisW + i * xStep;
        final y = legendH + chartH * (1 - pts[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);

      // Dots
      final dotPaint = Paint()..color = colors[s];
      for (int i = 0; i < pts.length; i++) {
        final x = axisW + i * xStep;
        final y = legendH + chartH * (1 - pts[i]);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }

    // Legend
    double lx = axisW;
    for (int s = 0; s < series.length; s++) {
      final dotPaint = Paint()..color = colors[s];
      canvas.drawCircle(Offset(lx + 5, 11), 4, dotPaint);
      _drawText(
        canvas,
        exerciseLabels[s],
        Offset(lx + 12, 4),
        TextStyle(
            color: colors[s].withValues(alpha: 0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600),
        width: 54,
      );
      lx += 64;
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.series != series || old.xLabels != xLabels;
}

// ── Arc painter (accuracy circles) ────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double value; // 0.0–1.0
  final Color color;
  _ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 6;
    const startAngle = -math.pi / 2;
    const strokeW = 8.0;

    // Track
    canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = Colors.white12
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW);

    // Fill
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
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
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}

// ── Text helper ───────────────────────────────────────────────────────────────

void _drawText(
  Canvas canvas,
  String text,
  Offset offset,
  TextStyle style, {
  double width = 60,
  TextAlign align = TextAlign.left,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  tp.paint(canvas, offset);
}
