import unittest

import main


class FakeVoiceCoach:
    use_elevenlabs = True

    def synthesize(self, text):
        return b"fake-mp3:" + text.encode("utf-8")


class TextToSpeechEndpointTest(unittest.TestCase):
    def setUp(self):
        self.previous_voice_coach = main.voice_coach
        main.voice_coach = FakeVoiceCoach()
        self.client = main.app.test_client()

    def tearDown(self):
        main.voice_coach = self.previous_voice_coach

    def test_tts_returns_audio_bytes(self):
        response = self.client.post("/tts", json={"text": "Sink lower."})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content_type, "audio/mpeg")
        self.assertEqual(response.data, b"fake-mp3:Sink lower.")

    def test_tts_requires_text(self):
        response = self.client.post("/tts", json={})

        self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
