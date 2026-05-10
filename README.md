# AI Fitness Coach

Real-time form tracking with MediaPipe pose detection, concise AI coaching cues, backend-owned voice playback, and a Flutter training UI.

## Project Structure

```
├── backend/              # Flask server + pose analysis
└── fitness_coach_app/    # Flutter mobile app
```

## Backend

The Flask backend receives camera frames from Flutter, analyzes movement with MediaPipe, returns live stats and pose landmarks, and plays coaching audio locally.

Production analyzers currently supported by the backend:

- `squat`
- `pushup`

Other exercise labels in the UI are placeholders until their analyzers are implemented and validated.

### Setup

```bash
cd backend
pip install -r requirements.txt
python download_model.py

cp .env.example .env
```

Edit `backend/.env` with the keys and voice settings you want:

```bash
ANTHROPIC_API_KEY=...
OPENAI_API_KEY=...

USE_ELEVENLABS_VOICE=true
ELEVENLABS_API_KEY=...
ELEVENLABS_VOICE_ID=...
ELEVENLABS_MODEL_ID=eleven_flash_v2_5

# Used only when ElevenLabs is disabled or unavailable.
MACOS_VOICE=samantha
```

ElevenLabs voice is played by the backend through macOS `afplay`. Flutter only displays the returned feedback text, so do not put ElevenLabs keys in the mobile app.

### Run

```bash
# Flask server for Flutter. Default port is 8080.
python main.py --exercise squat --mode beginner --provider claude
python main.py --exercise pushup --mode beginner --provider claude

# Standalone webcam demo (local testing)
python demo_webcam.py --exercise squat --mode beginner --provider claude
python demo_webcam.py --exercise pushup --mode beginner --provider claude
```

For squats and push-ups, use a clear side view, keep the full body in frame, and avoid fast camera movement.

## Frontend

Run the backend first, then start Flutter:

```bash
cd fitness_coach_app
flutter run -d chrome
```

The web app defaults to `http://127.0.0.1:8080`. On a real phone, change the server URL in the app settings to your Mac's local network IP, for example `http://192.168.1.x:8080`.

Current runtime behavior:

- Sends compressed frames to `/process_frame`.
- Uses backend stats and landmarks for the live overlay on web.
- Keeps feedback cues short for fast-paced movement, such as `Good rep.`, `Sink lower.`, `Chest up.`, and `Sit back.`
- Shows a session summary with statistics, per-exercise breakdown, and a celebration banner.

## Quick Branch Helper

If you want the local backend setup commands in one place, use the helper script at the repo root:

```bash
./run_local_backend.sh
```

This will create a `venv`, install backend dependencies, download the MediaPipe model, and print the commands to run the backend server and the standalone webcam demo.

## Useful API Endpoints

- `POST /configure` updates provider, mode, and exercise.
- `POST /process_frame` analyzes one frame and returns stats, landmarks, and any new feedback cue.
- `POST /reset` resets counters for the current analyzer.
- `GET /health` reports backend status.
