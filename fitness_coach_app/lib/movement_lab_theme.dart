import 'package:flutter/material.dart';

abstract final class MovementLabColors {
  static const porcelain = Color(0xFFF6F7F1);
  static const paper = Color(0xFFEEF1EA);
  static const paperLine = Color(0xFFDFE5DF);
  static const line = Color(0xFFCFD7CF);
  static const lineStrong = Color(0xFFAEB8AD);
  static const graphite = Color(0xFF252420);
  static const ink = Color(0xFF11110F);
  static const muted = Color(0xFF6A6F66);
  static const trackTeal = Color(0xFF006F73);
  static const tealSoft = Color(0xFFD5EFED);
  static const correct = Color(0xFF4E7F43);
  static const correctSoft = Color(0xFFDCEBD8);
  static const correction = Color(0xFFB64E3C);
  static const correctionSoft = Color(0xFFF0D8D1);
  static const tempo = Color(0xFFC89B2C);
  static const tempoSoft = Color(0xFFF2E7C5);
  static const white = Color(0xFFFFFFFF);
}

abstract final class MovementLabSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildMovementLabTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: MovementLabColors.graphite,
      secondary: MovementLabColors.trackTeal,
      error: MovementLabColors.correction,
      surface: MovementLabColors.white,
      onPrimary: MovementLabColors.white,
      onSecondary: MovementLabColors.white,
      onSurface: MovementLabColors.ink,
    ),
    scaffoldBackgroundColor: MovementLabColors.porcelain,
    useMaterial3: true,
    fontFamily: 'Aptos',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: MovementLabColors.graphite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: MovementLabColors.graphite,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: MovementLabColors.ink,
      displayColor: MovementLabColors.ink,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MovementLabColors.graphite,
        foregroundColor: MovementLabColors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const RoundedRectangleBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: MovementLabColors.graphite,
      foregroundColor: MovementLabColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: MovementLabColors.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: MovementLabColors.trackTeal, width: 2),
      ),
      labelStyle: TextStyle(color: MovementLabColors.muted),
      hintStyle: TextStyle(color: MovementLabColors.muted),
    ),
  );
}

class LabPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double borderWidth;

  const LabPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(MovementLabSpacing.md),
    this.color = MovementLabColors.white,
    this.borderColor = MovementLabColors.line,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A252420),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LabLabel extends StatelessWidget {
  final String text;
  final Color color;

  const LabLabel(
    this.text, {
    super.key,
    this.color = MovementLabColors.trackTeal,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );
  }
}

class CalibrationRule extends StatelessWidget {
  final Color color;

  const CalibrationRule({super.key, this.color = MovementLabColors.graphite});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(
        painter: _CalibrationRulePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CalibrationRulePainter extends CustomPainter {
  final Color color;

  const _CalibrationRulePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    for (double x = 0; x <= size.width; x += 18) {
      final tickHeight = x % 54 == 0 ? 18.0 : 10.0;
      canvas.drawLine(
        Offset(x, size.height / 2 - tickHeight / 2),
        Offset(x, size.height / 2 + tickHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalibrationRulePainter oldDelegate) =>
      oldDelegate.color != color;
}
