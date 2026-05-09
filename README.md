# AI Squat Trainer

Real-time squat form analysis with AI coaching feedback. Uses MediaPipe pose detection and Claude/OpenAI for personalized coaching.

## Project Structure

```
├── backend/              # Flask server + pose analysis
└── fitness_coach_app/    # Flutter mobile app
```

## Backend

Flask server that analyzes squat form using MediaPipe pose detection.

### Setup

```bash
cd backend
pip install -r requirements.txt
python download_model.py

cp .env.example .env
# Edit .env with your API keys:
#   ANTHROPIC_API_KEY=...
#   ELEVENLABS_API_KEY=...  # backend voice only
```

### Run

```bash
# Flask server (for mobile app)
python main.py
python main.py --mode pro --port 8080

# Standalone webcam demo (local testing)
python demo_webcam.py
python demo_webcam.py --provider claude
```

Stand sideways to the camera for best detection.

## Frontend

The Flutter app now sends feedback to the Python backend only. ElevenLabs voice playback is owned by the backend, so do not keep a separate ElevenLabs key in the mobile app.
