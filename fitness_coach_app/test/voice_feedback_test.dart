import 'package:fitness_coach_app/voice_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds backend TTS endpoint from server URL', () {
    final uri = backendTextToSpeechUri('http://127.0.0.1:5001');

    expect(uri.toString(), 'http://127.0.0.1:5001/tts');
  });

  test('builds backend TTS endpoint without duplicate slash', () {
    final uri = backendTextToSpeechUri('http://127.0.0.1:5001/');

    expect(uri.toString(), 'http://127.0.0.1:5001/tts');
  });

  test('builds backend TTS payload', () {
    final payload = backendTextToSpeechPayload('Sink lower.');

    expect(payload['text'], 'Sink lower.');
  });
}
