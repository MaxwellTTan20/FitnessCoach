const String _defaultElevenLabsVoiceId = 'VR6AewLTigWG4xSOukaG';
const String _defaultElevenLabsModelId = 'eleven_flash_v2_5';

class VoiceFeedbackConfig {
  const VoiceFeedbackConfig({
    required this.apiKey,
    required this.voiceId,
    required this.modelId,
  });

  final String apiKey;
  final String voiceId;
  final String modelId;

  bool get isEnabled => apiKey.trim().isNotEmpty;

  Uri get streamingUri => Uri.https(
        'api.elevenlabs.io',
        '/v1/text-to-speech/$voiceId/stream',
        const {
          'optimize_streaming_latency': '4',
          'output_format': 'mp3_22050_32',
        },
      );

  Map<String, String> get headers => {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
      };

  Map<String, Object> payloadFor(String text) => {
        'text': text,
        'model_id': modelId,
        'voice_settings': const <String, Object>{
          'stability': 0.50,
          'similarity_boost': 0.31,
          'style': 0.65,
          'use_speaker_boost': true,
        },
      };
}

const VoiceFeedbackConfig defaultVoiceFeedbackConfig = VoiceFeedbackConfig(
  apiKey: String.fromEnvironment('ELEVENLABS_KEY'),
  voiceId: String.fromEnvironment(
    'ELEVENLABS_VOICE_ID',
    defaultValue: _defaultElevenLabsVoiceId,
  ),
  modelId: String.fromEnvironment(
    'ELEVENLABS_MODEL_ID',
    defaultValue: _defaultElevenLabsModelId,
  ),
);
