import 'package:fitness_coach_app/audio_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the ding cue when correct reps increase', () {
    final cue = selectRepAudioCue(
      previousCorrectCount: 2,
      nextCorrectCount: 3,
      previousIncorrectCount: 1,
      nextIncorrectCount: 1,
    );

    expect(cue, RepAudioCue.ding);
  });

  test('selects the buzz cue when incorrect reps increase', () {
    final cue = selectRepAudioCue(
      previousCorrectCount: 2,
      nextCorrectCount: 2,
      previousIncorrectCount: 1,
      nextIncorrectCount: 2,
    );

    expect(cue, RepAudioCue.buzz);
  });

  test('does not select a cue when rep counts do not increase', () {
    final cue = selectRepAudioCue(
      previousCorrectCount: 2,
      nextCorrectCount: 2,
      previousIncorrectCount: 1,
      nextIncorrectCount: 1,
    );

    expect(cue, isNull);
  });
}
