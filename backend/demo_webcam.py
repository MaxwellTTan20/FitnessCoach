"""
Standalone webcam demo for testing SquatAnalyzer locally without the Flask server
or Flutter app. Use this to validate detection logic before exposing it through the API.

Usage:
    python demo_webcam.py                     # Basic test, no AI
    python demo_webcam.py --mode pro          # Pro thresholds
    python demo_webcam.py --provider claude   # With AI feedback (needs ANTHROPIC_API_KEY)
    python demo_webcam.py --provider claude --no-voice  # AI feedback without voice
"""
import argparse
import subprocess
import sys

from dotenv import load_dotenv
load_dotenv()

import cv2

from analyzer import SquatAnalyzer
from thresholds import THRESHOLDS

# --- Voice configuration (macOS `say` command) ---
VOICE_NAME = "Samantha"
VOICE_RATE = 200  # words per minute

# Module-level storage for the most recent rep data (for overlay display)
_last_rep_data = None
_last_ai_feedback = None

# Track the current speech subprocess for drop-stale playback
_current_speech = None


def speak(text: str) -> None:
    """
    Speak text using macOS `say` command.
    Terminates any in-progress speech before starting new speech (drop-stale).
    """
    global _current_speech

    try:
        # Terminate any in-progress speech
        if _current_speech is not None and _current_speech.poll() is None:
            _current_speech.terminate()

        # Start new speech
        _current_speech = subprocess.Popen(
            ["say", "-v", VOICE_NAME, "-r", str(VOICE_RATE), text],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        print(f"[Voice] Warning: Could not speak: {e}")


def stop_speech() -> None:
    """Stop any in-progress speech."""
    global _current_speech

    if _current_speech is not None and _current_speech.poll() is None:
        _current_speech.terminate()
        _current_speech = None


def draw_text_bg(frame, text, pos, font_scale=0.5, color=(255, 255, 255), thickness=1):
    """Draw text with a dark background rectangle for readability."""
    font = cv2.FONT_HERSHEY_SIMPLEX
    (text_w, text_h), baseline = cv2.getTextSize(text, font, font_scale, thickness)
    x, y = pos
    # Draw background rectangle
    cv2.rectangle(frame, (x - 2, y - text_h - 4), (x + text_w + 2, y + baseline), (0, 0, 0), -1)
    # Draw text
    cv2.putText(frame, text, (x, y), font, font_scale, color, thickness, cv2.LINE_AA)
    return text_h + baseline + 4  # Return height for stacking


def draw_overlays(frame, analyzer):
    """Draw debug overlays on the frame."""
    h, w = frame.shape[:2]
    y_offset = 20

    # --- Top left: state, counts, feedback ---
    y = y_offset
    y += draw_text_bg(frame, f"State: {analyzer.state}", (10, y))
    y += draw_text_bg(frame, f"Reps: {analyzer.correct_count} correct / {analyzer.incorrect_count} incorrect", (10, y))
    if analyzer.feedback:
        y += draw_text_bg(frame, f"Feedback: {analyzer.feedback}", (10, y), color=(0, 255, 255))

    # --- Top right: live angles ---
    angle_text1 = f"Knee: {analyzer.knee_angle:.1f}"
    angle_text2 = f"Hip: {analyzer.hip_angle:.1f}"
    # Right-align
    font = cv2.FONT_HERSHEY_SIMPLEX
    (tw1, _), _ = cv2.getTextSize(angle_text1, font, 0.5, 1)
    (tw2, _), _ = cv2.getTextSize(angle_text2, font, 0.5, 1)
    draw_text_bg(frame, angle_text1, (w - tw1 - 15, y_offset))
    draw_text_bg(frame, angle_text2, (w - tw2 - 15, y_offset + 20))

    # --- Bottom left: last rep info ---
    if _last_rep_data:
        rep = _last_rep_data
        y = h - 160
        y += draw_text_bg(frame, f"--- Last Rep #{rep.get('rep_number', '?')} ---", (10, y), color=(200, 200, 200))
        status = "GOOD" if rep.get("is_correct") else "BAD"
        color = (0, 255, 0) if rep.get("is_correct") else (0, 0, 255)
        y += draw_text_bg(frame, f"Form: {status}", (10, y), color=color)
        y += draw_text_bg(frame, f"Knee angle: {rep.get('knee_angle', 0):.1f} (at depth)", (10, y))
        y += draw_text_bg(frame, f"Hip angle: {rep.get('hip_angle', 0):.1f} (at depth)", (10, y))

        # Trajectory info
        traj = rep.get("rep_trajectory", [])
        deepest_idx = rep.get("deepest_frame_index")
        y += draw_text_bg(frame, f"Trajectory: {len(traj)} frames, deepest @ {deepest_idx}", (10, y), color=(180, 180, 255))

        # Tempo
        tempo = rep.get("tempo", {})
        descent = tempo.get('descent_seconds')
        ascent = tempo.get('ascent_seconds')
        tempo_status = tempo.get('status', 'unknown')
        descent_str = f"{descent:.1f}s" if descent is not None else "?"
        ascent_str = f"{ascent:.1f}s" if ascent is not None else "?"
        # Color based on tempo status
        if tempo_status == "ok":
            tempo_color = (180, 255, 180)  # green
        elif tempo_status == "unknown":
            tempo_color = (180, 180, 180)  # gray
        else:
            tempo_color = (0, 0, 255)  # red for rushed/bounced
        y += draw_text_bg(frame, f"Tempo: {descent_str} down / {ascent_str} up ({tempo_status})", (10, y), color=tempo_color)

    # Show AI feedback if available
    if _last_ai_feedback:
        # Bottom right
        font = cv2.FONT_HERSHEY_SIMPLEX
        # Wrap long feedback
        max_chars = 40
        lines = [_last_ai_feedback[i:i+max_chars] for i in range(0, len(_last_ai_feedback), max_chars)]
        y = h - 20 - (len(lines) - 1) * 20
        for line in lines:
            (tw, _), _ = cv2.getTextSize(line, font, 0.45, 1)
            draw_text_bg(frame, line, (w - tw - 15, y), font_scale=0.45, color=(0, 255, 200))
            y += 18


def pretty_print_rep(rep_data):
    """Print rep data in a readable format, truncating rep_trajectory if present."""
    print("\n" + "=" * 50)
    print(f"REP #{rep_data.get('rep_number', '?')} COMPLETE")
    print("=" * 50)
    for key, value in rep_data.items():
        if key == "rep_trajectory":
            # Truncate large trajectory data
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
    """Create the on_rep_complete callback."""
    def on_rep_complete(rep_data):
        global _last_rep_data, _last_ai_feedback

        _last_rep_data = rep_data
        pretty_print_rep(rep_data)

        if ai_coach:
            try:
                feedback = ai_coach.get_feedback(rep_data)
                print(f"[AI Coach] {feedback}")
                _last_ai_feedback = feedback

                # Speak feedback if voice is enabled
                if use_voice:
                    speak(feedback)
            except Exception as e:
                print(f"[AI Coach Error] {e}")
                _last_ai_feedback = None

    return on_rep_complete


def parse_resolution(res_str):
    """Parse 'WxH' string into (width, height) tuple."""
    try:
        parts = res_str.lower().split("x")
        return int(parts[0]), int(parts[1])
    except (ValueError, IndexError):
        print(f"Invalid resolution format: {res_str}. Use WxH (e.g., 640x480)")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Standalone webcam demo for SquatAnalyzer")
    parser.add_argument("--mode", choices=["beginner", "pro"], default="beginner",
                        help="Squat mode (default: beginner)")
    parser.add_argument("--resolution", default="640x480",
                        help="Camera resolution WxH (default: 640x480)")
    parser.add_argument("--provider", choices=["claude", "openai", "none"], default="none",
                        help="AI provider for feedback (default: none)")
    parser.add_argument("--camera-index", type=int, default=0,
                        help="Camera index (default: 0)")
    parser.add_argument("--no-voice", action="store_true",
                        help="Disable voice feedback (default: voice enabled when AI provider is set)")
    args = parser.parse_args()

    width, height = parse_resolution(args.resolution)

    # Initialize AI coach if requested
    ai_coach = None
    if args.provider != "none":
        try:
            from ai_coach import AICoach
            ai_coach = AICoach(provider=args.provider)
            print(f"AI Coach initialized: {args.provider}")
        except Exception as e:
            print(f"Warning: Could not initialize AI coach: {e}")
            print("Continuing without AI feedback...")

    # Determine if voice is enabled (AI provider set and --no-voice not passed)
    use_voice = (args.provider != "none") and (not args.no_voice)

    # Print startup banner
    print()
    print("=" * 55)
    print("  SQUAT TRAINER - Webcam Demo")
    print("=" * 55)
    print(f"  Mode:       {args.mode}")
    print(f"  Resolution: {width}x{height}")
    print(f"  Camera:     index {args.camera_index}")
    print(f"  AI:         {args.provider}")
    print(f"  Voice:      {'enabled' if use_voice else 'disabled'}")
    print("-" * 55)
    print("  Stand sideways to camera.")
    print("  Press 'q' or ESC to quit, 'r' to reset counters.")
    print("=" * 55)
    print()

    # Open webcam
    cap = cv2.VideoCapture(args.camera_index)
    if not cap.isOpened():
        print(f"Error: Could not open camera at index {args.camera_index}")
        sys.exit(1)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)

    # Verify actual resolution
    actual_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    actual_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    if actual_w != width or actual_h != height:
        print(f"Note: Camera using {actual_w}x{actual_h} (requested {width}x{height})")

    # Initialize analyzer
    callback = create_rep_callback(ai_coach, use_voice=use_voice)
    analyzer = SquatAnalyzer(mode=args.mode, on_rep_complete=callback)
    current_mode = args.mode

    print("Camera opened. Starting capture...")

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Error: Failed to read frame from camera")
                break

            # Process frame through analyzer
            annotated = analyzer.process_frame(frame)

            # Draw our debug overlays
            draw_overlays(annotated, analyzer)

            # Show frame
            cv2.imshow("Squat Trainer Demo", annotated)

            # Handle keyboard input
            key = cv2.waitKey(1) & 0xFF
            if key == ord("q") or key == 27:  # 'q' or ESC
                print("\nQuitting...")
                break
            elif key == ord("r"):
                analyzer.reset()
                global _last_rep_data, _last_ai_feedback
                _last_rep_data = None
                _last_ai_feedback = None
                print("\n[Reset] Counters cleared")
            elif key == ord("m"):
                # Toggle mode - would need to reinitialize thresholds
                # The analyzer stores self.thresh but doesn't have a clean way to switch
                # without recreating. For now, just print a note.
                new_mode = "pro" if current_mode == "beginner" else "beginner"
                print(f"\n[Mode toggle] Switching {current_mode} -> {new_mode}")
                analyzer.reset()
                analyzer.mode = new_mode
                analyzer.thresh = THRESHOLDS[new_mode]
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
