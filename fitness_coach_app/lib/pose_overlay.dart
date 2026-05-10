import 'package:flutter/material.dart';

bool shouldShowPoseOverlay({
  required bool hasLandmarks,
  required bool isProcessing,
}) {
  return hasLandmarks;
}

Offset mapNormalizedPointToCover({
  required Offset normalizedPoint,
  required Size sourceSize,
  required Size destinationSize,
}) {
  if (sourceSize.isEmpty || destinationSize.isEmpty) {
    return Offset.zero;
  }

  final scale = mathMax(
    destinationSize.width / sourceSize.width,
    destinationSize.height / sourceSize.height,
  );
  final fittedWidth = sourceSize.width * scale;
  final fittedHeight = sourceSize.height * scale;
  final offsetX = (destinationSize.width - fittedWidth) / 2;
  final offsetY = (destinationSize.height - fittedHeight) / 2;

  return Offset(
    offsetX + normalizedPoint.dx * fittedWidth,
    offsetY + normalizedPoint.dy * fittedHeight,
  );
}

double mathMax(double a, double b) => a > b ? a : b;
