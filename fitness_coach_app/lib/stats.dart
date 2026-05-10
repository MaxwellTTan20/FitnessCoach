import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'user_profile.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _exerciseColors = [
  Color(0xFF1E88E5), // Squat    – blue
  Color(0xFFE53935), // Bench    – red
  Color(0xFF78909C), // Deadlift – blue-grey
  Color(0xFF43A047), // Push-up  – green
];

// Approximate kcal burned per rep (all-comers average, 70 kg person).
const _caloriesPerRep = {
  'Squat':    0.50,
  'Bench':    0.32,
  'Deadlift': 0.60,
  'Push-up':  0.35,
};

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
  final int refreshTrigger;
  const StatsPage({super.key, this.refreshTrigger = 0});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _Period _period = _Period.week;
  bool _loading = true;

  // Raw sessions pulled once from Firestore; reused across period switches.
  List<Map<String, dynamic>> _allSessions = [];

  // Computed for the current period.
  List<int>    _reps        = List.filled(4, 0);
  List<double> _accuracy    = List.filled(4, 0.0);
  List<List<double>> _progression = List.generate(4, (_) => []);
  int _calories = 0;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void didUpdateWidget(StatsPage old) {
    super.didUpdateWidget(old);
    if (old.refreshTrigger != widget.refreshTrigger) {
      setState(() => _loading = true);
      _loadSessions();
    }
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    final uid = AppProfile.instance.auth0UserId;
    if (uid != null && uid.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sessions')
            .orderBy('completedAt')
            .get();
        _allSessions = snap.docs.map((d) => d.data()).toList();
      } catch (e) {
        debugPrint('[Stats] load error: $e');
      }
    }
    _computeStats();
  }

  // ── Stats computation ──────────────────────────────────────────────────────

  void _computeStats() {
    final now = DateTime.now();
    final start = _periodStart(now);
    final numBuckets = _period.xLabels.length;

    // Sessions in the selected window.
    final sessions = _allSessions.where((s) {
      final ts = s['completedAt'] as Timestamp?;
      if (ts == null) return false;
      return !ts.toDate().isBefore(start);
    }).toList();

    final reps    = List.filled(4, 0);
    final correct = List.filled(4, 0);
    final total   = List.filled(4, 0);
    var caloriesF = 0.0;

    // progression[exerciseIdx][bucketIdx] = (correct, total) pairs
    final progCorrect = List.generate(4, (_) => List.filled(numBuckets, 0));
    final progTotal   = List.generate(4, (_) => List.filled(numBuckets, 0));

    for (final session in sessions) {
      final ts = (session['completedAt'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final bucket = _timeBucket(ts, now);
      if (bucket < 0 || bucket >= numBuckets) continue;

      final lifts = (session['lifts'] as List<dynamic>?) ?? [];
      for (final raw in lifts) {
        final lift = raw as Map<String, dynamic>;
        final name = lift['exercise'] as String? ?? '';
        final idx  = AppProfile.exercises.indexOf(name);
        if (idx < 0) continue;

        final lCorrect   = (lift['correctCount']   as num? ?? 0).toInt();
        final lIncorrect = (lift['incorrectCount']  as num? ?? 0).toInt();
        final lTotal     = lCorrect + lIncorrect;

        reps[idx]    += lTotal;
        correct[idx] += lCorrect;
        total[idx]   += lTotal;

        progCorrect[idx][bucket] += lCorrect;
        progTotal[idx][bucket]   += lTotal;

        caloriesF += lTotal * (_caloriesPerRep[name] ?? 0.35);
      }
    }

    setState(() {
      _loading = false;
      _reps = reps;
      _accuracy = List.generate(4, (i) =>
          total[i] > 0 ? correct[i] / total[i] : 0.0);
      _progression = List.generate(4, (i) =>
          List.generate(numBuckets, (j) =>
              progTotal[i][j] > 0
                  ? progCorrect[i][j] / progTotal[i][j]
                  : 0.0));
      _calories = caloriesF.round();
    });
  }

  DateTime _periodStart(DateTime now) {
    switch (_period) {
      case _Period.day:
        return DateTime(now.year, now.month, now.day);
      case _Period.week:
        // Start on Monday of the current week.
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case _Period.month:
        return DateTime(now.year, now.month, 1);
      case _Period.year:
        return DateTime(now.year, 1, 1);
    }
  }

  // Returns the 0-based bucket index for a session timestamp.
  int _timeBucket(DateTime dt, DateTime now) {
    switch (_period) {
      case _Period.day:
        if (dt.hour < 6)  return -1; // before 6am — skip
        if (dt.hour < 9)  return 0;
        if (dt.hour < 12) return 1;
        if (dt.hour < 15) return 2;
        if (dt.hour < 18) return 3;
        if (dt.hour < 21) return 4;
        return 5;
      case _Period.week:
        return dt.weekday - 1; // 0=Mon … 6=Sun
      case _Period.month:
        return ((dt.day - 1) / 7).floor().clamp(0, 3);
      case _Period.year:
        return ((dt.month - 1) / 2).floor(); // 0=Jan-Feb … 5=Nov-Dec
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent))
            : ListView(
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
              onTap: () {
                _period = p;      // set before computeStats calls setState
                _computeStats();
              },
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
                'Estimated from all attempted reps',
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
    const textStyle = TextStyle(color: Colors.white38, fontSize: 10);

    // Horizontal grid lines + Y axis labels
    for (int i = 0; i <= gridLines; i++) {
      final y = chartH * (1 - i / gridLines);
      canvas.drawLine(Offset(axisW, y), Offset(size.width, y), gridPaint);
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
      final left  = axisW + i * barGroupW + barInset;
      final right = axisW + (i + 1) * barGroupW - barInset;
      final top   = chartH - barH;

      final barPaint = Paint()
        ..color = values[i] == 0
            ? colors[i].withValues(alpha: 0.2)
            : colors[i];

      final rr = RRect.fromLTRBR(
          left, top, right, chartH, const Radius.circular(6));
      canvas.drawRRect(rr, barPaint);

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
  bool shouldRepaint(_BarChartPainter old) => old.values != values;
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
    const legendH  = 24.0;
    const xLabelH  = 20.0;
    const axisW    = 34.0;
    const gridLines = 4;

    final chartH = size.height - legendH - xLabelH;
    final chartW = size.width - axisW;

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    const axisTextStyle = TextStyle(color: Colors.white38, fontSize: 10);

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

    canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = Colors.white12
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW);

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
