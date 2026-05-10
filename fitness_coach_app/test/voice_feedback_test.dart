import 'package:fitness_coach_app/voice_feedback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default voice config has no checked-in API key', () {
    expect(defaultVoiceFeedbackConfig.apiKey, isEmpty);
    expect(defaultVoiceFeedbackConfig.isEnabled, isFalse);
  });

  test('builds ElevenLabs streaming endpoint for low latency playback', () {
    const config = VoiceFeedbackConfig(
      apiKey: 'test-key',
      voiceId: 'voice-123',
      modelId: 'eleven_flash_v2_5',
    );

    final uri = config.streamingUri;

    expect(uri.scheme, 'https');
    expect(uri.host, 'api.elevenlabs.io');
    expect(uri.path, '/v1/text-to-speech/voice-123/stream');
    expect(uri.queryParameters['optimize_streaming_latency'], '4');
    expect(uri.queryParameters['output_format'], 'mp3_22050_32');
  });

  test('builds ElevenLabs headers and payload', () {
    const config = VoiceFeedbackConfig(
      apiKey: 'test-key',
      voiceId: 'voice-123',
      modelId: 'eleven_flash_v2_5',
    );

    expect(config.headers['xi-api-key'], 'test-key');
    expect(config.headers['Content-Type'], 'application/json');

    final payload = config.payloadFor('Sink lower.');

    expect(payload['text'], 'Sink lower.');
    expect(payload['model_id'], 'eleven_flash_v2_5');
    expect(payload['voice_settings'], isA<Map<String, Object>>());
  });
}
