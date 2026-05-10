"""
Voice module - backend TTS using ElevenLabs or macOS say fallback.
"""
import os
import subprocess
import tempfile
import threading

MACOS_VOICES = ["samantha", "alex", "victoria", "karen", "daniel"]

VOICES = {
    "gentleman": "4FGncSQuErxZLM0p4qHJ",  # creator tier only
    "rachel": "21m00Tcm4TlvDq8ikWAM",
    "clyde": "2EiwWnXFnvU5JabPnv8n",
    "domi": "AZnzlk1XvdvUeBnXmlld",
    "bella": "EXAVITQu4vr4xnSDxMaL",
    "antoni": "ErXwobaYiN019PkySvjV",
    "elli": "MF3mGyEYCl7XYWbV9V6O",
    "josh": "TxGEqnHWrfWFTfGW9XjX",
    "arnold": "VR6AewLTigWG4xSOukaG",
    "adam": "pNInz6obpgDQGcFmaJgB",
    "sam": "yoZ06aMxZJJ28mfd3POQ",
}


class VoiceCoach:
    def __init__(
        self,
        api_key: str | None = None,
        voice_id: str = "arnold",
        model_id: str = "eleven_flash_v2_5",
        use_elevenlabs: bool = True,
    ):
        self.use_elevenlabs = use_elevenlabs
        self.voice_id = voice_id
        self.model_id = model_id
        self._speech_lock = threading.Lock()

        if use_elevenlabs:
            self.api_key = api_key or os.environ.get("ELEVENLABS_API_KEY")
            if not self.api_key:
                raise ValueError("ElevenLabs API key required.")
            from elevenlabs.client import ElevenLabs
            self.client = ElevenLabs(api_key=self.api_key)
            self.voice_id = self._resolve_voice_id(voice_id)
        else:
            if self.voice_id.lower() not in MACOS_VOICES:
                self.voice_id = "samantha"
            self.client = None

    def _resolve_voice_id(self, name: str) -> str:
        """Resolve a voice name to its ElevenLabs ID using the local VOICES dict."""
        key = name.lower()
        if key in VOICES:
            resolved = VOICES[key]
            print(f"[Voice] '{name}' → {resolved}")
            return resolved
        # Assume it's already a raw voice ID
        print(f"[Voice] Using '{name}' as raw voice ID.")
        return name

    def speak(self, text: str) -> None:
        if not self._speech_lock.acquire(blocking=False):
            print("[Voice] Speech already in progress; skipping overlapping request.")
            return

        try:
            if self.use_elevenlabs:
                self._speak_elevenlabs(text)
            else:
                self._speak_macos(text)
        finally:
            self._speech_lock.release()

    def synthesize(self, text: str) -> bytes:
        if not self.use_elevenlabs or self.client is None:
            raise RuntimeError("ElevenLabs synthesis is not enabled.")

        audio = self.client.text_to_speech.convert(
            text=text,
            voice_id=self.voice_id,
            model_id=self.model_id,
            output_format="mp3_22050_32",
        )
        return b"".join(audio)

    def _speak_elevenlabs(self, text: str) -> None:
        try:
            print(f"[Voice] Speaking with voice_id={self.voice_id!r}: {text[:50]}")
            audio_bytes = self.synthesize(text)
            if not audio_bytes:
                print("[Voice] ElevenLabs returned empty audio.")
                return

            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as audio_file:
                audio_file.write(audio_bytes)
                audio_path = audio_file.name
            try:
                result = subprocess.run(
                    ["afplay", audio_path],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    check=False,
                )
                if result.returncode == 0:
                    print(f"[Voice] Played ElevenLabs audio ({len(audio_bytes)} bytes).")
                else:
                    print(
                        "[Voice] afplay failed: "
                        f"code={result.returncode} stderr={result.stderr.strip()}"
                    )
            finally:
                try:
                    os.remove(audio_path)
                except OSError:
                    pass
        except Exception as e:
            print(f"[Voice] ElevenLabs error: {e}")

    def _speak_macos(self, text: str) -> None:
        try:
            safe_text = text.replace('"', '\\"')
            subprocess.Popen(
                ["say", "-v", self.voice_id, safe_text],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"[Voice] macOS say error: {e}")
