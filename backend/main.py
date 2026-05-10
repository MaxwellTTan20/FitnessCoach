"""
Flask server for AI Fitness Coach.
Receives frames from the Flutter app, processes with MediaPipe + AI coaching, returns annotated frames.
TTS is handled by the Flutter app (ElevenLabs called directly from the phone).

Setup:
    1. Copy .env.example to .env and fill in your API keys.
    2. Keys are loaded automatically via python-dotenv, or source .env before running.

Run: python main.py [--exercise squat|pushup] [--mode beginner|pro]
"""
import argparse
import base64
import io
import os
import socket
import threading

from dotenv import load_dotenv
load_dotenv()

import cv2
import numpy as np
from flask import Flask, jsonify, request
from flask_cors import CORS
from PIL import Image  # still used for JPEG decode on inbound frame

from ai_coach import AICoach
from analyzer import SquatAnalyzer, PushupAnalyzer, DeadliftAnalyzer, BenchAnalyzer

app = Flask(__name__)
CORS(app)

analyzer = None
ai_coach = None
_pending_ai_feedback = ""
current_exercise = "squat"
current_mode = "beginner"

EXERCISE_CLASSES = {
    "squat": SquatAnalyzer,
    "pushup": PushupAnalyzer,
    "deadlift": DeadliftAnalyzer,
    "bench": BenchAnalyzer,
}


def normalize_exercise(name: str) -> str:
    """Normalize exercise name to a key in EXERCISE_CLASSES."""
    return name.lower().replace("-", "").replace(" ", "")


def create_analyzer(exercise: str, mode: str, callback):
    cls = EXERCISE_CLASSES.get(normalize_exercise(exercise))
    if cls is None:
        raise ValueError(f"No analyzer available for exercise '{exercise}'. "
                         f"Supported: {list(EXERCISE_CLASSES.keys())}")
    return cls(mode=mode, on_rep_complete=callback)


def configure_ai_coach(provider="claude", anthropic_key=None, openai_key=None, exercise="squat"):
    global ai_coach

    if not provider:
        ai_coach = None
        return

    anthropic_key = anthropic_key or os.environ.get("ANTHROPIC_API_KEY")
    openai_key = openai_key or os.environ.get("OPENAI_API_KEY")

    if anthropic_key:
        os.environ["ANTHROPIC_API_KEY"] = anthropic_key
    if openai_key:
        os.environ["OPENAI_API_KEY"] = openai_key

    api_key = anthropic_key if provider == "claude" else openai_key
    ai_coach = AICoach(provider=provider, api_key=api_key, exercise=exercise)


def create_feedback_callback():
    def on_rep_complete(rep_data):
        def process_feedback():
            global _pending_ai_feedback, ai_coach
            try:
                if ai_coach:
                    feedback = ai_coach.get_feedback(rep_data)
                    print(f"[AI Coach] {feedback}")
                    _pending_ai_feedback = feedback
                else:
                    print(f"[Rep Complete] {rep_data}")
            except Exception as e:
                print(f"[AI Coach Error] {e}")

        threading.Thread(target=process_feedback, daemon=True).start()

    return on_rep_complete


@app.route("/process_frame", methods=["POST"])
def process_frame():
    global _pending_ai_feedback
    try:
        data = request.get_json()
        if not data or "image" not in data:
            return jsonify({"error": "No image provided"}), 400

        image_data = base64.b64decode(data["image"])
        image = Image.open(io.BytesIO(image_data))
        frame = np.array(image)
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        analyzer.process_frame(frame)

        ai_feedback = _pending_ai_feedback
        _pending_ai_feedback = ""

        return jsonify({
            "stats": analyzer.get_stats_for_api(),
            "landmarks": analyzer.last_pose_landmarks,
            "ai_feedback": ai_feedback,
        })

    except Exception as e:
        print(f"Error processing frame: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/process_landmarks", methods=["POST"])
def process_landmarks():
    global _pending_ai_feedback
    try:
        data = request.get_json()
        raw_landmarks = data.get("landmarks", [])
        analyzer.process_landmarks(raw_landmarks)
        ai_feedback = _pending_ai_feedback
        _pending_ai_feedback = ""
        return jsonify({
            "stats": analyzer.get_stats_for_api(),
            "ai_feedback": ai_feedback,
        })
    except Exception as e:
        print(f"Error processing landmarks: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/configure", methods=["POST"])
def configure():
    global analyzer, current_exercise, current_mode
    try:
        data = request.get_json(force=True)
        provider = data.get("provider", "claude")
        anthropic_key = data.get("anthropic_key")
        openai_key = data.get("openai_key")
        exercise = normalize_exercise(data.get("exercise", current_exercise))
        mode = data.get("mode", current_mode)

        configure_ai_coach(
            provider=provider,
            anthropic_key=anthropic_key,
            openai_key=openai_key,
            exercise=exercise,
        )

        # Recreate analyzer only if exercise or mode changed
        if exercise != current_exercise or mode != current_mode:
            if analyzer is not None:
                analyzer.close()
            analyzer = create_analyzer(exercise, mode, create_feedback_callback())
            current_exercise = exercise
            current_mode = mode

        return jsonify({"success": True, "provider": provider, "exercise": exercise, "mode": mode})
    except Exception as e:
        print(f"Error configuring backend: {e}")
        return jsonify({"success": False, "error": str(e)}), 400


@app.route("/status", methods=["GET"])
def status():
    return jsonify({
        "provider": ai_coach.provider if ai_coach else None,
        "has_ai_coach": ai_coach is not None,
        "exercise": current_exercise,
        "mode": analyzer.mode if analyzer else None,
    })


@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"})


@app.route("/reset", methods=["POST"])
def reset():
    try:
        analyzer.reset()
        return jsonify({"message": "Counters reset"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI Fitness Coach — Server")
    parser.add_argument("--exercise", choices=list(EXERCISE_CLASSES.keys()), default="squat")
    parser.add_argument("--mode", choices=["beginner", "pro"], default="beginner")
    parser.add_argument("--port", type=int, default=5000)
    parser.add_argument("--provider", choices=["claude", "openai"], default="claude")
    parser.add_argument("--anthropic-key", default=None)
    parser.add_argument("--openai-key", default=None)
    args = parser.parse_args()

    current_exercise = args.exercise
    current_mode = args.mode

    on_rep_callback = create_feedback_callback()
    analyzer = create_analyzer(args.exercise, args.mode, on_rep_callback)

    try:
        configure_ai_coach(
            provider=args.provider,
            anthropic_key=args.anthropic_key,
            openai_key=args.openai_key,
            exercise=args.exercise,
        )
        print(f"AI Coach: {args.provider} (TTS handled by phone)")
    except Exception as e:
        print(f"Warning: Could not initialize AI coach: {e}")
        print("Continuing without AI coaching...")

    try:
        local_ip = socket.gethostbyname(socket.gethostname())
    except Exception:
        local_ip = "unknown"
    print(f"Exercise: {args.exercise} | Mode: {args.mode} | Port: {args.port}")
    print(f"╔══════════════════════════════════════╗")
    print(f"║  Set Flutter server URL to:          ║")
    print(f"║  http://{local_ip}:{args.port}".ljust(39) + "║")
    print(f"╚══════════════════════════════════════╝")
    app.run(host="0.0.0.0", port=args.port, debug=False)
