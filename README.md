# 🦦 CapyCoach

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Python](https://img.shields.io/badge/Python-3.9+-yellow)
![License](https://img.shields.io/badge/license-MIT-green)

An ultra-low latency, AI-powered personal training application with built-in gamification. CapyCoach uses real-time computer vision to track your exercise form and provides instant, personalized voice feedback powered by Large Language Models (Anthropic/OpenAI) and ElevenLabs.

---

## ✨ Key Features

- **Gamified Fitness (Feed the Capybara)**: Earn "grass" by completing correct reps with good form! Use your earned grass to feed and unlock up to 10 different Capybara characters in the app's interactive feeder screen.
- **Real-Time Pose Tracking**: Uses MediaPipe to track 33 body landmarks with zero noticeable delay.
- **Multi-Exercise Support**: Production-ready form analyzers for:
  - `squat` (Depth, Torso lean)
  - `pushup` (Elbow depth, Plank alignment, Shoulder flare)
  - `deadlift` (Hip hinge, Knee bend)
  - `bench` (Elbow depth, Shoulder tuck, Back arch)
- **Zero-Latency Voice Coaching**: Unlike traditional setups, audio is generated entirely on the Flutter frontend via ElevenLabs' flash streaming model, drastically reducing Time-To-First-Byte (TTFB).
- **Intelligent LLM Feedback**: Hardcoded robotic phrases are completely removed. The coach passes your exact joint angles to Anthropic's Claude Haiku to dynamically generate highly varied, context-aware coaching (e.g., *"Hinge deeper, don't jerk the ascent"*).
- **Native Canvas Overlays**: Uses Flutter `CustomPainter` to draw skeletal tracking overlays directly on the browser/native canvas, eliminating the massive bandwidth overhead of transmitting base64 images.

---

## 🏗️ Architecture

1. **Client (Flutter)**: Captures web/mobile camera frames at high speed.
2. **Vision Server (Flask)**: Processes frames via MediaPipe and returns skeletal coordinates and raw angle calculations.
3. **AI Logic (Python)**: Analyzes the rep against strict biomechanical thresholds and passes contextual hints to the LLM.
4. **TTS Engine (Client-Side)**: The LLM text is instantly streamed to ElevenLabs by the Flutter app for immediate audio playback with native playback rate multipliers.

---

## 🚀 Setup & Installation

### 1. Backend (Computer Vision & LLM)

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python download_model.py
```

Set up your `.env` file in the `backend` directory:
```bash
# Used for backend CLI testing or fallback logic
ANTHROPIC_API_KEY=your_anthropic_key
ELEVENLABS_API_KEY=your_elevenlabs_key
```

### 2. Frontend (Flutter UI & Audio)

To keep API keys completely out of source code and Git history, pass your credentials securely via compile-time variables. 

```bash
cd fitness_coach_app

flutter run -d chrome \
  --dart-define=ANTHROPIC_KEY=your_anthropic_key \
  --dart-define=ELEVENLABS_KEY=your_elevenlabs_key \
  --dart-define=SERVER_URL=http://127.0.0.1:5001
```

*(Note: Change `SERVER_URL` to your Mac's local network IP if testing on a physical iOS/Android device).*

---

## 🏃‍♂️ Usage

Start the backend server on port 5001. Choose your exercise and your preferred AI provider (`claude` is recommended for lowest latency).

```bash
# Start Deadlift Coach
python backend/main.py --port 5001 --exercise deadlift --provider claude

# Start Squat Coach
python backend/main.py --port 5001 --exercise squat --provider claude

# Start Pushup Coach
python backend/main.py --port 5001 --exercise pushup --provider claude

# Start Bench Press Coach
python backend/main.py --port 5001 --exercise bench --provider claude
```

Once the server is running, launch the Flutter app, select your camera, and start your set!

---

## 🛠️ Advanced Configuration

### Threshold Calibration
Biomechanical thresholds can be easily adjusted in `backend/thresholds.py`. 
- **Beginner Mode**: Generous form thresholds.
- **Pro Mode**: Strict form thresholds (e.g. Squat depth requires `<60°` knee angle instead of `90°`).

### Voice Customization
To change the ElevenLabs voice character, modify the `ELEVENLABS_VOICE_ID` compile-time variable in Flutter.
