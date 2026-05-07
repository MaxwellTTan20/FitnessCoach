"""
Flask server for AI Squat Trainer.
Receives frames from the Flutter app, processes with MediaPipe + AI coaching, returns annotated frames.
TTS is handled by the Flutter app (ElevenLabs called directly from the phone).

Run: python main.py [--mode pro]
"""
import argparse
import base64
import io
import os
import threading

import cv2
import numpy as np
from flask import Flask, jsonify, request
from flask_cors import CORS
from PIL import Image

from ai_coach import AICoach
from analyzer import SquatAnalyzer

ANTHROPIC_API_KEY = "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"

app = Flask(__name__)
CORS(app)

analyzer = None
ai_coach = None
_pending_ai_feedback = ""


def configure_ai_coach(provider="claude", anthropic_key=ANTHROPIC_API_KEY, openai_key=None):
    global ai_coach

    if not provider:
        ai_coach = None
        return

    if anthropic_key:
        os.environ["ANTHROPIC_API_KEY"] = anthropic_key
    if openai_key:
        os.environ["OPENAI_API_KEY"] = openai_key

    api_key = anthropic_key if provider == "claude" else openai_key
    ai_coach = AICoach(provider=provider, api_key=api_key)


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

        annotated_frame = analyzer.process_frame(frame)
        annotated_frame_rgb = cv2.cvtColor(annotated_frame, cv2.COLOR_BGR2RGB)

        _, buffer = cv2.imencode(".jpg", annotated_frame_rgb, [cv2.IMWRITE_JPEG_QUALITY, 85])
        annotated_b64 = base64.b64encode(buffer).decode("utf-8")

        # Grab and clear any pending AI feedback so the phone can speak it.
        ai_feedback = _pending_ai_feedback
        _pending_ai_feedback = ""

        stats = {
            "correct_count": analyzer.correct_count,
            "incorrect_count": analyzer.incorrect_count,
            "current_feedback": analyzer.feedback,
            "is_in_rep": analyzer.state == "squatting",
            "knee_angle": round(analyzer.knee_angle, 1),
            "hip_angle": round(analyzer.hip_angle, 1),
            "state": analyzer.state,
        }

        return jsonify({
            "annotated_image": annotated_b64,
            "stats": stats,
            "landmarks": analyzer.last_pose_landmarks,
            "ai_feedback": ai_feedback,
        })

    except Exception as e:
        print(f"Error processing frame: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/configure", methods=["POST"])
def configure():
    try:
        data = request.get_json(force=True)
        provider = data.get("provider", "claude")
        anthropic_key = data.get("anthropic_key") or ANTHROPIC_API_KEY
        openai_key = data.get("openai_key")

        configure_ai_coach(provider=provider, anthropic_key=anthropic_key, openai_key=openai_key)

        return jsonify({"success": True, "provider": provider})
    except Exception as e:
        print(f"Error configuring backend: {e}")
        return jsonify({"success": False, "error": str(e)}), 400


@app.route("/status", methods=["GET"])
def status():
    return jsonify({
        "provider": ai_coach.provider if ai_coach else None,
        "has_ai_coach": ai_coach is not None,
        "mode": analyzer.mode if analyzer else None,
    })


@app.route("/reset", methods=["POST"])
def reset():
    try:
        analyzer.reset()
        return jsonify({"message": "Counters reset"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI Squat Trainer — Server")
    parser.add_argument("--mode", choices=["beginner", "pro"], default="beginner")
    parser.add_argument("--port", type=int, default=5000)
    parser.add_argument("--provider", choices=["claude", "openai"], default="claude")
    parser.add_argument("--anthropic-key", default=ANTHROPIC_API_KEY)
    parser.add_argument("--openai-key", default=None)
    args = parser.parse_args()

    on_rep_callback = create_feedback_callback()
    analyzer = SquatAnalyzer(mode=args.mode, on_rep_complete=on_rep_callback)

    try:
        configure_ai_coach(
            provider=args.provider,
            anthropic_key=args.anthropic_key,
            openai_key=args.openai_key,
        )
        print(f"AI Coach: {args.provider} (TTS handled by phone)")
    except Exception as e:
        print(f"Warning: Could not initialize AI coach: {e}")
        print("Continuing without AI coaching...")

    print(f"Mode: {args.mode} | Starting on http://0.0.0.0:{args.port}")
    app.run(host="0.0.0.0", port=args.port, debug=False)
