"""
Standalone webcam demo for testing exercise analyzers locally without the Flask server
or Flutter app. Use this to validate detection logic before exposing it through the API.

Usage:
    python demo_webcam.py                              # Squat, beginner, no AI
    python demo_webcam.py --exercise pushup            # Push-up analyzer
    python demo_webcam.py --exercise squat --mode pro  # Squat with pro thresholds
    python demo_webcam.py --provider claude            # With AI feedback
    python demo_webcam.py --provider claude --no-voice # AI feedback without voice
"""
import argparse
import subprocess
import sys
import threading

from dotenv import load_dotenv
load_dotenv()

import cv2

from analyzer import SquatAnalyzer, PushupAnalyzer
from thresholds import SQUAT_THRESHOLDS, PUSHUP_THRESHOLDS
from voice import VoiceCoach

EXERCISE_CLASSES = {
    "squat": SquatAnalyzer,
    "pushup": PushupAnalyzer,
}

EXERCISE_THRESHOLDS = {
    "squat": SQUAT_THRESHOLDS,
    "pushup": PUSHUP_THRESHOLDS,
}

# --- Voice configuration (macOS `say` command) ---
VOICE_NAME = "Samantha"
VOICE_RATE = 200

# Optional backend-style VoiceCoach (ElevenLabs)
_voice_coach = None
try:
    use_elevenlabs = os.environ.get("USE_ELEVENLABS_VOICE", "true").lower() not in {"0", "false", "no", "off"}
    api_key = os.environ.get("ELEVENLABS_API_KEY")
    voice_id = os.environ.get("ELEVENLABS_VOICE_ID")
    if use_elevenlabs and api_key:
        _voice_coach = VoiceCoach(api_key=api_key, voice_id=voice_id, use_elevenlabs=True)
except Exception as e:
    print(f"[Voice] Could not initialize VoiceCoach: {e}")

_last_rep_data = None
_last_ai_feedback = None
_current_speech = None
_speech_lock = threading.Lock()


def speak(text: str) -> None:
    global _current_speech
    with _speech_lock:
        try:
            # Prefer VoiceCoach when available (ElevenLabs)
            if _voice_coach is not None:
                _voice_coach.speak(text)
                return
            if _current_speech is not None and _current_speech.poll() is None:
                _current_speech.terminate()
            _current_speech = subprocess.Popen(
                ["say", "-v", VOICE_NAME, "-r", str(VOICE_RATE), text],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"[Voice] Warning: Could not speak: {e}")


def stop_speech() -> None:
    global _current_speech
    with _speech_lock:
        if _current_speech is not None and _current_speech.poll() is None:
            _current_speech.terminate()
            _current_speech = None


def draw_text_bg(frame, text, pos, font_scale=0.5, color=(255, 255, 255), thickness=1):
    font = cv2.FONT_HERSHEY_SIMPLEX
    (text_w, text_h), baseline = cv2.getTextSize(text, font, font_scale, thickness)
    x, y = pos
    cv2.rectangle(frame, (x - 2, y - text_h - 4), (x + text_w + 2, y + baseline), (0, 0, 0), -1)
    cv2.putText(frame, text, (x, y), font, font_scale, color, thickness, cv2.LINE_AA)
    return text_h + baseline + 4


def draw_overlays(frame, analyzer):
    h, w = frame.shape[:2]
    y_offset = 20

    # --- Top left: state, counts, feedback ---
    y = y_offset
    y += draw_text_bg(frame, f"State: {analyzer.state}", (10, y))
    y += draw_text_bg(frame, f"Reps: {analyzer.correct_count} correct / {analyzer.incorrect_count} incorrect", (10, y))
    if analyzer.feedback:
        y += draw_text_bg(frame, f"Feedback: {analyzer.feedback}", (10, y), color=(0, 255, 255))

    # --- Top right: live angles from the analyzer ---
    font = cv2.FONT_HERSHEY_SIMPLEX
    right_y = y_offset
    for label, value in analyzer.get_angle_labels():
        text = f"{label}: {value:.1f}"
        (tw, _), _ = cv2.getTextSize(text, font, 0.5, 1)
        draw_text_bg(frame, text, (w - tw - 15, right_y))
        right_y += 20

    # --- Bottom left: last rep info ---
    if _last_rep_data:
        rep = _last_rep_data
        y = h - 180
        y += draw_text_bg(frame, f"--- Last Rep #{rep.get('rep_number', '?')} ---", (10, y), color=(200, 200, 200))
        status = "GOOD" if rep.get("is_correct") else "BAD"
        color = (0, 255, 0) if rep.get("is_correct") else (0, 0, 255)
        y += draw_text_bg(frame, f"Form: {status}", (10, y), color=color)

        # Show all angle values stored in the rep data
        for key, val in rep.items():
            if key.endswith("_angle") and isinstance(val, (int, float)):
                label = key.replace("_", " ").title()
                y += draw_text_bg(frame, f"{label}: {val:.1f} (at depth)", (10, y))

        # Trajectory info
        traj = rep.get("rep_trajectory", [])
        deepest_idx = rep.get("deepest_frame_index")
        y += draw_text_bg(frame, f"Trajectory: {len(traj)} frames, deepest @ {deepest_idx}", (10, y), color=(180, 180, 255))

        # Tempo
        tempo = rep.get("tempo", {})
        descent = tempo.get("descent_seconds")
        ascent = tempo.get("ascent_seconds")
        tempo_status = tempo.get("status", "unknown")
        descent_str = f"{descent:.1f}s" if descent is not None else "?"
        ascent_str = f"{ascent:.1f}s" if ascent is not None else "?"
        tempo_color = (180, 255, 180) if tempo_status == "ok" else (
            (180, 180, 180) if tempo_status == "unknown" else (0, 0, 255)
        )
        y += draw_text_bg(frame, f"Tempo: {descent_str} down / {ascent_str} up ({tempo_status})", (10, y), color=tempo_color)

    # --- Bottom right: AI feedback ---
    if _last_ai_feedback:
        max_chars = 40
        lines = [_last_ai_feedback[i:i+max_chars] for i in range(0, len(_last_ai_feedback), max_chars)]
        y = h - 20 - (len(lines) - 1) * 20
        for line in lines:
            (tw, _), _ = cv2.getTextSize(line, font, 0.45, 1)
            draw_text_bg(frame, line, (w - tw - 15, y), font_scale=0.45, color=(0, 255, 200))
            y += 18


def pretty_print_rep(rep_data):
    print("\n" + "=" * 50)
    print(f"REP #{rep_data.get('rep_number', '?')} COMPLETE")
    print("=" * 50)
    for key, value in rep_data.items():
        if key == "rep_trajectory":
            if isinstance(value, (list, tuple)):
                print(f"  {key}: <{len(value)} frames>")
            else:
                print(f"  {key}: <truncated>")
        elif isinstance(value, float):
            print(f"  {key}: {value:.2f}")
        else:
            print(f"  {key}: {value}")
    print("=" * 50)


def create_rep_callback(ai_coach=None, use_voice=False):
    def on_rep_complete(rep_data):
        global _last_rep_data, _last_ai_feedback
        _last_rep_data = rep_data
        pretty_print_rep(rep_data)

        def process_async():
            global _last_ai_feedback
            if ai_coach is not None:
                try:
                    feedback = ai_coach.get_feedback(rep_data)
                    print(f"[AI Coach] {feedback}")
                    _last_ai_feedback = feedback
                    if use_voice:
                        speak(feedback)
                except Exception as e:
                    print(f"[AI Coach Error] {e}")

        if ai_coach is not None:
            threading.Thread(target=process_async, daemon=True).start()

    return on_rep_complete


def parse_resolution(res_str):
    try:
        parts = res_str.lower().split("x")
        return int(parts[0]), int(parts[1])
    except (ValueError, IndexError):
        print(f"Invalid resolution format: {res_str}. Use WxH (e.g., 640x480)")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Standalone webcam demo for exercise analyzers")
    parser.add_argument("--exercise", choices=list(EXERCISE_CLASSES.keys()), default="squat",
                        help="Exercise to analyze (default: squat)")
    parser.add_argument("--mode", choices=["beginner", "pro"], default="beginner",
                        help="Difficulty mode (default: beginner)")
    parser.add_argument("--resolution", default="640x480",
                        help="Camera resolution WxH (default: 640x480)")
    parser.add_argument("--provider", choices=["claude", "openai", "none"], default="none",
                        help="AI provider for feedback (default: none)")
    parser.add_argument("--camera-index", type=int, default=0,
                        help="Camera index (default: 0)")
    parser.add_argument("--no-voice", action="store_true",
                        help="Disable voice feedback")
    args = parser.parse_args()

    width, height = parse_resolution(args.resolution)

    ai_coach = None
    if args.provider != "none":
        try:
            from ai_coach import AICoach
            ai_coach = AICoach(provider=args.provider, exercise=args.exercise)
            print(f"AI Coach initialized: {args.provider} ({args.exercise})")
        except Exception as e:
            print(f"Warning: Could not initialize AI coach: {e}")
            print("Continuing without AI feedback...")

    use_voice = (args.provider != "none") and (not args.no_voice)

    print()
    print("=" * 55)
    print(f"  FITNESS COACH - Webcam Demo")
    print("=" * 55)
    print(f"  Exercise:   {args.exercise}")
    print(f"  Mode:       {args.mode}")
    print(f"  Resolution: {width}x{height}")
    print(f"  Camera:     index {args.camera_index}")
    print(f"  AI:         {args.provider}")
    print(f"  Voice:      {'enabled' if use_voice else 'disabled'}")
    print("-" * 55)
    if args.exercise == "pushup":
        print("  Get into push-up position (side view).")
    else:
        print("  Stand sideways to camera.")
    print("  Press 'q' or ESC to quit, 'r' to reset counters.")
    print("  Press 'm' to toggle beginner/pro mode.")
    print("=" * 55)
    print()

    cap = cv2.VideoCapture(args.camera_index)
    if not cap.isOpened():
        print(f"Error: Could not open camera at index {args.camera_index}")
        sys.exit(1)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)

    actual_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    actual_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    if actual_w != width or actual_h != height:
        print(f"Note: Camera using {actual_w}x{actual_h} (requested {width}x{height})")

    callback = create_rep_callback(ai_coach, use_voice=use_voice)
    AnalyzerClass = EXERCISE_CLASSES[args.exercise]
    analyzer = AnalyzerClass(mode=args.mode, on_rep_complete=callback)
    current_mode = args.mode

    print("Camera opened. Starting capture...")

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Error: Failed to read frame from camera")
                break

            annotated = analyzer.process_frame(frame)
            draw_overlays(annotated, analyzer)
            cv2.imshow(f"Fitness Coach Demo — {args.exercise.title()}", annotated)

            key = cv2.waitKey(1) & 0xFF
            if key == ord("q") or key == 27:
                print("\nQuitting...")
                break
            elif key == ord("r"):
                analyzer.reset()
                global _last_rep_data, _last_ai_feedback
                _last_rep_data = None
                _last_ai_feedback = None
                print("\n[Reset] Counters cleared")
            elif key == ord("m"):
                new_mode = "pro" if current_mode == "beginner" else "beginner"
                print(f"\n[Mode toggle] Switching {current_mode} -> {new_mode}")
                analyzer.reset()
                analyzer.mode = new_mode
                thresholds = EXERCISE_THRESHOLDS[args.exercise]
                analyzer.thresh = thresholds[new_mode]
                current_mode = new_mode
                print(f"[Mode toggle] Now using {current_mode} thresholds")

    except KeyboardInterrupt:
        print("\nInterrupted by user")
    finally:
        stop_speech()
        cap.release()
        cv2.destroyAllWindows()
        analyzer.close()
        print("Cleanup complete.")


if __name__ == "__main__":
    main()
