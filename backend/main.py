"""
Flask server for AI Fitness Coach.
Receives frames from the Flutter app, processes with MediaPipe + AI coaching, returns annotated frames.
Voice playback is handled by the backend.

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
import time

from dotenv import load_dotenv
load_dotenv()

import cv2
import numpy as np
from flask import Flask, jsonify, request
from flask_cors import CORS
from PIL import Image

from ai_coach import AICoach
from analyzer import SquatAnalyzer, PushupAnalyzer, DeadliftAnalyzer, BenchAnalyzer
from voice import VoiceCoach

app = Flask(__name__)
CORS(app)

analyzer = None
ai_coach = None
voice_coach = None
_pending_ai_feedback = ""
_latest_rep_number = 0
current_exercise = "squat"
current_mode = "beginner"

EXERCISE_CLASSES = {
    "squat": SquatAnalyzer,
    "pushup": PushupAnalyzer,
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


def configure_voice_coach():
    global voice_coach

    use_elevenlabs = os.environ.get("USE_ELEVENLABS_VOICE", "true").lower() not in {"0", "false", "no", "off"}
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    voice_id = os.environ.get("ELEVENLABS_VOICE_ID", "arnold")
    model_id = os.environ.get("ELEVENLABS_MODEL_ID", "eleven_flash_v2_5")

    if not use_elevenlabs:
        voice_id = os.environ.get("MACOS_VOICE", "samantha")

    if use_elevenlabs and not api_key:
        print("[Voice] ELEVENLABS_API_KEY not set; falling back to macOS say.")
        use_elevenlabs = False
        voice_id = os.environ.get("MACOS_VOICE", "samantha")

    try:
        voice_coach = VoiceCoach(
            api_key=api_key,
            voice_id=voice_id,
            model_id=model_id,
            use_elevenlabs=use_elevenlabs,
        )
        provider = "ElevenLabs" if use_elevenlabs else "macOS say"
        print(f"[Voice] Initialized {provider} voice with model {model_id}.")
    except Exception as e:
        print(f"[Voice] Could not initialize voice coach: {e}")
        voice_coach = None


def create_feedback_callback():
    def on_rep_complete(rep_data):
        global _latest_rep_number
        rep_number = rep_data.get("rep_number", 0)
        _latest_rep_number = max(_latest_rep_number, rep_number)

        def process_feedback():
            global _pending_ai_feedback, ai_coach, voice_coach
            try:
                tempo = rep_data.get("tempo", {})
                print(
                    "[Rep] "
                    f"#{rep_data.get('rep_number')} "
                    f"correct={rep_data.get('is_correct')} "
                    f"knee={rep_data.get('knee_angle', 0):.0f} "
                    f"hip={rep_data.get('hip_angle', 0):.0f} "
                    f"tempo={tempo.get('status')} "
                    f"descent={tempo.get('descent_seconds')} "
                    f"ascent={tempo.get('ascent_seconds')}",
                    flush=True,
                )
                if ai_coach:
                    feedback = ai_coach.get_feedback(rep_data)
                    if rep_number < _latest_rep_number:
                        print(
                            f"[AI Coach] Dropping stale feedback for rep #{rep_number}",
                            flush=True,
                        )
                        return
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
    request_started_at = time.perf_counter()
    try:
        data = request.get_json()
        if not data or "image" not in data:
            return jsonify({"error": "No image provided"}), 400
        include_annotated = data.get("include_annotated", True)

        decode_started_at = time.perf_counter()
        image_data = base64.b64decode(data["image"])
        image = Image.open(io.BytesIO(image_data))
        frame = np.array(image)
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        frame_height, frame_width = frame.shape[:2]

        analysis_started_at = time.perf_counter()
        annotated_frame = analyzer.process_frame(frame)

        encode_started_at = time.perf_counter()
        annotated_b64 = None
        if include_annotated:
            annotated_frame_rgb = cv2.cvtColor(annotated_frame, cv2.COLOR_BGR2RGB)
            _, buffer = cv2.imencode(".jpg", annotated_frame_rgb, [cv2.IMWRITE_JPEG_QUALITY, 85])
            annotated_b64 = base64.b64encode(buffer).decode("utf-8")

        ai_feedback = _pending_ai_feedback
        _pending_ai_feedback = ""

        stats = analyzer.get_stats_for_api()
        total_ms = int((time.perf_counter() - request_started_at) * 1000)
        print(
            "[Frame] "
            f"total={total_ms}ms "
            f"decode={int((analysis_started_at - decode_started_at) * 1000)}ms "
            f"analyze={int((encode_started_at - analysis_started_at) * 1000)}ms "
            f"encode={int((time.perf_counter() - encode_started_at) * 1000)}ms "
            f"size={frame_width}x{frame_height} "
            f"landmarks={len(analyzer.last_pose_landmarks)}",
            flush=True,
        )

        return jsonify({
            "annotated_image": annotated_b64,
            "stats": stats,
            "landmarks": analyzer.last_pose_landmarks,
            "frame_width": frame_width,
            "frame_height": frame_height,
            "ai_feedback": ai_feedback,
        })

    except Exception as e:
        print(f"Error processing frame: {e}")
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
        "voice_enabled": voice_coach is not None,
        "voice_mode": "elevenlabs" if voice_coach and voice_coach.use_elevenlabs else ("macos" if voice_coach else None),
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


@app.route("/speak", methods=["POST"])
def speak():
    """Convert text to speech using the configured voice."""
    try:
        data = request.get_json()
        if not data or "text" not in data:
            return jsonify({"error": "No text provided"}), 400
        
        text = data.get("text")
        
        if not voice_coach:
            return jsonify({"error": "Voice coach not initialized"}), 500
        
        # Speak the text (voice_coach handles both TTS and playback)
        voice_coach.speak(text)
        
        return jsonify({"success": True, "text": text})
    except Exception as e:
        print(f"Error in /speak: {e}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI Fitness Coach — Server")
    parser.add_argument("--exercise", choices=list(EXERCISE_CLASSES.keys()), default="squat")
    parser.add_argument("--mode", choices=["beginner", "pro"], default="beginner")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--provider", choices=["claude", "openai"], default="claude")
    parser.add_argument("--anthropic-key", default=None)
    parser.add_argument("--openai-key", default=None)
    args = parser.parse_args()

    current_exercise = args.exercise
    current_mode = args.mode

    configure_voice_coach()
    on_rep_callback = create_feedback_callback()
    analyzer = create_analyzer(args.exercise, args.mode, on_rep_callback)

    try:
        configure_ai_coach(
            provider=args.provider,
            anthropic_key=args.anthropic_key,
            openai_key=args.openai_key,
            exercise=args.exercise,
        )
        print(f"AI Coach: {args.provider} (voice handled by backend)")
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
