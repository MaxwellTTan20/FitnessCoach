import 'package:fitness_coach_app/frame_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests annotated frames on native targets', () {
    expect(shouldRequestAnnotatedFrame(isWeb: false), isTrue);
  });

  test('skips annotated frames on web targets', () {
    expect(shouldRequestAnnotatedFrame(isWeb: true), isFalse);
  });
}
