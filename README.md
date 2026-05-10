# CapyCoach

AI-powered fitness form coaching built with Flutter, MediaPipe, Firebase, Auth0, and LLM feedback.

CapyCoach helps lifters train with more awareness by using a camera feed to analyze exercise form, count reps, provide coaching feedback, save workout history, and turn progress into a small capybara reward loop.

This repository is the main application branch: a full Flutter app backed by a Python pose-analysis server.

## Core Features

- **Camera-based form tracking:** The Flutter app streams camera frames to a Python backend for pose analysis.
- **Exercise-specific analyzers:** Squat, bench, deadlift, and push-up support with separate movement thresholds.
- **AI coaching feedback:** Claude or OpenAI can generate short coaching feedback from completed rep metrics.
- **Voice feedback:** ElevenLabs voice support is available for spoken feedback during sessions.
- **Workout flows:** Users can start single-exercise workouts, warm-ups, or preset plans.
- **Session summaries:** Completed sessions show total reps, correct reps, incorrect reps, accuracy, and per-exercise breakdowns.
- **Progress stats:** Signed-in users can review saved reps, form accuracy, progression, and estimated calories.
- **Authentication:** Auth0 Google sign-in with guest mode for quick testing.
- **Persistent profiles:** Firebase stores signed-in user profile and workout history.
- **Capybara gamification:** Correct reps earn grass that can be used to feed and evolve the capybara companion.

## Demo Flow

1. Start the Flask backend.
2. Launch the Flutter app.
3. Sign in with Google or continue as guest.
4. Choose a workout or tap the camera button.
5. Perform reps from a clear side profile.
6. Finish the session.
7. Review session stats and feed the capybara with earned grass.

## Tech Stack

### Frontend

- Flutter
- `camera` for native camera capture
- `http` for backend communication
- `audioplayers` for voice playback
- Auth0 for Google sign-in
- Firebase Core and Cloud Firestore
- SharedPreferences for local profile/settings

### Backend

- Python Flask
- MediaPipe pose landmarker
- OpenCV and NumPy for frame processing
- Claude or OpenAI for AI coaching feedback
- ElevenLabs or macOS voice fallback

## Repository Structure

```text
.
├── backend/              # Flask API, pose analyzers, AI coach, voice module
└── fitness_coach_app/    # Flutter app, auth, workouts, stats, capybara UI
```

## Backend Setup

From the repository root:

```bash
cd backend
pip install -r requirements.txt
python download_model.py
```

Create `backend/.env`:

```env
ANTHROPIC_API_KEY=your_anthropic_key
OPENAI_API_KEY=your_openai_key
ELEVENLABS_API_KEY=your_elevenlabs_key

# Optional
USE_ELEVENLABS_VOICE=true
ELEVENLABS_VOICE_ID=arnold
ELEVENLABS_MODEL_ID=eleven_flash_v2_5
```

Run the backend:

```bash
python main.py --exercise squat --provider claude --port 8080
```

Supported backend exercises:

```text
squat
pushup
deadlift
bench
```

The backend prints the URL that the Flutter app should use. For a physical iPhone, use your Mac's local network IP instead of `localhost`.

## Flutter Setup

```bash
cd fitness_coach_app
flutter pub get
flutter run
```

For a physical iPhone:

1. Keep the backend running on your Mac.
2. Make sure the Mac and iPhone are on the same Wi-Fi network.
3. Set the app backend URL to `http://<your-mac-ip>:8080`.
4. Build/run from Xcode or Flutter with a valid signing team.

For web testing:

```bash
flutter run -d chrome
```

Auth0 web login requires localhost callback/origin URLs to be configured in Auth0. Guest mode is the fastest path for quick local web demos.

## Running the Backend Webcam Demo

The backend also includes a standalone webcam demo:

```bash
cd backend
python demo_webcam.py --exercise squat --provider claude
```

Use a clear side profile and keep the full body visible for best tracking.

## Data Model

Signed-in users are stored under `users/{auth0UserId}` in Firestore. Workout sessions are saved as subcollection documents with:

- exercise name
- correct rep count
- incorrect rep count
- total reps
- accuracy
- completion timestamp

The Stats tab aggregates those saved sessions into reps per exercise, form accuracy, progression charts, and estimated calories.

## App Notes

- The pose model performs best from the side, with the lifter fully visible.
- Guest sessions are useful for demos, but signed-in users get persistent history.
- The capybara reward loop uses correct reps as the progression source.
- On macOS, port `5000` may be occupied by AirPlay Receiver; use `8080` if needed.

## Security Notes

API keys should be kept out of committed source and loaded from environment variables or `.env` files. Before public deployment, rotate any development keys, confirm `.env` is ignored, and avoid shipping secret values inside the Flutter client.

## Useful Commands

Backend:

```bash
cd backend
python main.py --exercise squat --provider claude --port 8080
```

Flutter:

```bash
cd fitness_coach_app
flutter pub get
flutter run
```

Tests:

```bash
cd fitness_coach_app
flutter test
```
