# Backend Setup Instructions

## Prerequisites
- Python 3.9+
- MediaPipe model downloaded (run this first):

```bash
cd hackdavisPrototype1
python download_model.py
```

## Run the Backend Server

### Option 1: Basic mode (no AI coaching, just pose detection)
```bash
cd hackdavisPrototype1
python server.py
```

### Option 2: With Claude AI coaching (recommended)
```bash
cd hackdavisPrototype1
python server.py --provider claude
```

The server will start on `http://localhost:5000`

## Configure the App

1. Open the Flutter app and tap **Record**
2. Tap the **settings icon** (⚙️) in the top right
3. Enter your configuration:
   - **AI provider**: `claude` or `openai`
   - **Anthropic API key**: Your API key (or leave blank if using OpenAI)
   - **OpenAI API key**: Your API key (or leave blank if using Claude)
   - **ElevenLabs API key**: Set on the backend if you want backend voice playback
   - **Voice ID**: Configure on the backend with `ELEVENLABS_VOICE_ID`
   - **Use ElevenLabs voice**: Configure on the backend with `USE_ELEVENLABS_VOICE`
4. Tap **Save backend config**
5. Tap **Start** to begin recording

## Troubleshooting

If you see "Backend not configured" or no pose detection:
1. Make sure the server is running (`python server.py` in hackdavisPrototype1)
2. Check your internet connection
3. On iOS simulator, the URL is `http://localhost:5000`
4. On Android emulator, change the URL to `http://10.0.2.2:5000` in `lib/record_page.dart` line 55

## Testing Without the App

To test the backend directly:
```bash
cd hackdavisPrototype1
python webcam_demo.py --mode beginner --provider claude
```

Press 'q' to quit, 'r' to reset counters.
