# Fitness Coach App

A Flutter app with AI-powered squat analysis and voice coaching.

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Set up the Python backend:
   ```bash
   cd hackdavisPrototype1
   pip install -r requirements.txt
   python download_model.py  # Download MediaPipe model
   ```

3. Run the Python server:
   ```bash
   python server.py --provider claude  # or openai
   ```
   Note: Set your API keys as environment variables:
   - `ANTHROPIC_API_KEY` for Claude
   - `OPENAI_API_KEY` for OpenAI
   - `ELEVENLABS_API_KEY` for voice (optional)

4. Update the server URL in `lib/record_page.dart` if needed (default: `http://localhost:5000` for iOS simulator, `http://10.0.2.2:5000` for Android emulator). If running server on a different machine, use the IP address.

5. Run the Flutter app:
   ```bash
   flutter run
   ```

## Mobile Setup

- Ensure your phone and server are on the same Wi-Fi network.
- For iOS: Use `http://<server-ip>:5000`
- For Android: Use `http://10.0.2.2:5000` if server is on the same machine as emulator, or `<server-ip>:5000` for physical device.

## Features

- Live camera feed with pose detection
- Real-time squat form analysis
- AI voice coaching feedback
- Rep counting and form correction
- Aesthetic UI with lifting themes
- Responsive design for mobile devices
