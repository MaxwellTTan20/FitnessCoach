Uri backendTextToSpeechUri(String serverUrl) {
  final trimmed = serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
  return Uri.parse('$trimmed/tts');
}

Map<String, String> backendTextToSpeechPayload(String text) => {'text': text};
