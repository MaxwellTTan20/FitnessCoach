import 'package:fitness_coach_app/pose_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows pose overlay while processing when landmarks exist', () {
    expect(
      shouldShowPoseOverlay(hasLandmarks: true, isProcessing: true),
      isTrue,
    );
  });

  test('hides pose overlay when no landmarks exist', () {
    expect(
      shouldShowPoseOverlay(hasLandmarks: false, isProcessing: true),
      isFalse,
    );
  });

  test('maps normalized points through BoxFit cover crop', () {
    final mapped = mapNormalizedPointToCover(
      normalizedPoint: const Offset(0.5, 0.5),
      sourceSize: const Size(720, 480),
      destinationSize: const Size(300, 300),
    );

    expect(mapped.dx, closeTo(150, 0.01));
    expect(mapped.dy, closeTo(150, 0.01));
  });
}
