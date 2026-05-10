# CapyCoach

Real-time AI form coaching for strength training, built for HackDavis.

CapyCoach turns a phone or laptop camera into a lightweight workout coach. It watches each rep, classifies form in real time, gives instant correct/incorrect audio cues, and uses an LLM plus ElevenLabs speech to deliver short spoken coaching before the next rep starts.

Built in a 24-hour hackathon environment, the project focuses on one clear idea: make form feedback immediate, understandable, and fun enough that someone would actually keep using it.

## What Makes It Stand Out

- **Real-time pose analysis:** MediaPipe-powered backend tracks body landmarks frame by frame.
- **Four exercise analyzers:** Squat, bench, deadlift, and push-up each have exercise-specific thresholds and coaching context.
- **Instant audio cues:** Correct and incorrect reps trigger immediate local sound effects, so feedback is never delayed by the LLM.
- **LLM coaching after each rep:** Claude or OpenAI receives structured rep metrics, tempo, tracked side, landmark confidence, and form context.
- **Short voice feedback:** Spoken coaching is pruned to short responses so it fits between reps and avoids overtalking.
- **Backend ElevenLabs TTS:** API keys stay on the backend instead of being shipped in the Flutter client.
- **Low-bandwidth web path:** Web can request pose landmarks without the heavy annotated frame, then draw the stick overlay in Flutter.
- **Workout history and stats:** Signed-in users can save sessions to Firebase and review reps, accuracy, progression, and estimated calories.
- **Gamified retention loop:** Correct reps earn grass, which feeds and evolves the capybara companion.

## Demo Flow

1. Sign in with Google or continue as guest.
2. Pick an exercise or warm-up.
3. Start the camera and perform reps from a side view.
4. Hear an immediate ding or buzz when a rep is counted.
5. Hear concise AI voice coaching after completed reps.
6. Finish the session to view accuracy and per-exercise totals.
7. Feed your capybara with grass earned from correct reps.

## Tech Stack

### Frontend

- Flutter
- Camera plugin
- Auth0 login
- Firebase / Cloud Firestore
- Local audio playback with `audioplayers`
- SharedPreferences for local profile and settings

### Backend

- Python Flask
- MediaPipe pose landmarker
- OpenCV / NumPy frame processing
- Claude or OpenAI for coaching feedback
- ElevenLabs for speech synthesis
- Exercise-specific analyzers for squat, bench, deadlift, and push-up

## Architecture

```text
Flutter camera
    -> JPEG frame
    -> Flask /process_frame
    -> MediaPipe landmarks
    -> exercise analyzer
    -> rep stats + landmark coordinates
    -> Flutter UI overlay + audio cues

Completed rep
    -> structured rep metrics
    -> Claude/OpenAI coaching
    -> backend /tts
    -> ElevenLabs audio bytes
    -> Flutter playback

Finished session
    -> session summary
    -> Firebase session save for signed-in users
    -> stats dashboard
    -> capybara reward loop
```

## Repository Structure

```text
.
├── backend/              # Flask API, MediaPipe analyzers, AI coach, TTS
└── fitness_coach_app/    # Flutter app, auth, camera UI, stats, capybara
```

## Backend Setup

Create `backend/.env`:

```env
ANTHROPIC_API_KEY=your_anthropic_key
ELEVENLABS_API_KEY=your_elevenlabs_key

# Optional
OPENAI_API_KEY=your_openai_key
ANTHROPIC_MODEL=claude-sonnet-4-6
ELEVENLABS_VOICE_ID=arnold
ELEVENLABS_MODEL_ID=eleven_flash_v2_5
USE_ELEVENLABS_VOICE=true
```

Install dependencies and download the MediaPipe model:

```bash
cd backend
pip install -r requirements.txt
python download_model.py
```

Run the backend:

```bash
python main.py --exercise squat --provider claude --port 5000
```

For a physical phone, use your computer's local network IP:

```bash
python main.py --exercise squat --provider claude --port 8080
```

Then set the app's backend URL to `http://<your-computer-ip>:8080` from the in-app backend settings.

## Flutter Setup

```bash
cd fitness_coach_app
flutter pub get
flutter run
```

Optional compile-time configuration:

```bash
flutter run \
  --dart-define=SERVER_URL=http://localhost:5000 \
  --dart-define=AI_PROVIDER=claude
```

For web testing:

```bash
flutter run -d chrome \
  --dart-define=SERVER_URL=http://localhost:5000
```

## Supported Exercises

- Squat: knee depth, hip/torso position, tempo
- Bench: elbow depth, body position, shoulder/elbow flare reliability
- Deadlift: hip hinge depth, knee position, tempo
- Push-up: elbow depth, body alignment, shoulder/elbow flare reliability

The current pose model works best from a clear side profile with the full body visible.

## Data and Accounts

- Auth0 handles Google sign-in.
- Firebase stores signed-in user profiles and session history.
- Guest mode is available for quick demos.
- Stats are generated from saved session documents.
- Capybara progress is tied to correct reps and saved through the profile layer.

## Hackathon Notes

This was built under HackDavis time pressure, so the priority was a complete end-to-end product loop over a polished production backend:

- camera input
- real-time pose detection
- rep classification
- immediate audio cues
- LLM coaching
- spoken feedback
- saved progress
- stats dashboard
- capybara reward system

The core demo is intentionally practical: do a rep, get feedback, save the workout, and see progress.

## Tests

Backend unit tests:

```bash
cd backend
python -m unittest discover -s . -p "test_*.py"
```

Flutter tests:

```bash
cd fitness_coach_app
flutter test
```

## Security

API keys should live in `backend/.env`. The current integration branch keeps ElevenLabs calls on the backend so the Flutter client does not need to ship the ElevenLabs key.
