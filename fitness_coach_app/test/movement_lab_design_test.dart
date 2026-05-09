import 'package:fitness_coach_app/movement_lab_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Movement Lab tokens use light instrument surfaces and semantic accents',
    () {
      expect(MovementLabColors.porcelain, const Color(0xFFF6F7F1));
      expect(MovementLabColors.graphite, const Color(0xFF252420));
      expect(MovementLabColors.trackTeal, const Color(0xFF006F73));
      expect(MovementLabColors.correction, const Color(0xFFB64E3C));
    },
  );

  test('Movement Lab theme is not the old dark-mode Material theme', () {
    final theme = buildMovementLabTheme();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, MovementLabColors.porcelain);
    expect(theme.colorScheme.primary, MovementLabColors.graphite);
  });
}
