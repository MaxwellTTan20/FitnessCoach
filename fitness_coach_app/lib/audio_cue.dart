const String _dingAssetPath = 'audio/ding.m4a';
const String _buzzAssetPath = 'audio/buzz.m4a';

enum RepAudioCue {
  ding(_dingAssetPath),
  buzz(_buzzAssetPath);

  const RepAudioCue(this.assetPath);

  final String assetPath;
}

RepAudioCue? selectRepAudioCue({
  required int previousCorrectCount,
  required int nextCorrectCount,
  required int previousIncorrectCount,
  required int nextIncorrectCount,
}) {
  if (nextCorrectCount > previousCorrectCount) {
    return RepAudioCue.ding;
  }
  if (nextIncorrectCount > previousIncorrectCount) {
    return RepAudioCue.buzz;
  }
  return null;
}
