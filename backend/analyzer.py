import time
import os
import statistics
import cv2
import mediapipe as mp

from utils import (
    LANDMARKS, find_angle, find_offset_angle,
    get_landmark_coords_from_normalized,
)
from thresholds import (
    OFFSET_THRESH, INACTIVE_THRESH, THRESHOLDS,
    BUFFER_KNEE_START, BUFFER_KNEE_END, BUFFER_TIMEOUT_SECONDS,
)

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
RunningMode = mp.tasks.vision.RunningMode

POSE_CONNECTIONS = mp.tasks.vision.PoseLandmarksConnections.POSE_LANDMARKS

MODEL_PATH = os.path.join(os.path.dirname(__file__), "pose_landmarker_heavy.task")


class SquatAnalyzer:
    def __init__(self, mode="beginner", on_rep_complete=None):
        self.mode = mode
        self.thresh = THRESHOLDS[mode]
        self.on_rep_complete = on_rep_complete
        self.last_pose_landmarks = []

        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(
                f"Model not found at {MODEL_PATH}\n"
                "Run: python download_model.py"
            )

        options = PoseLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=MODEL_PATH),
            running_mode=RunningMode.VIDEO,
            num_poses=1,
            min_pose_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        self.landmarker = PoseLandmarker.create_from_options(options)
        self.frame_timestamp_ms = 0

        self.correct_count = 0
        self.incorrect_count = 0
        self.state = "standing"
        self.feedback = ""
        self.knee_angle = 0.0
        self.hip_angle = 0.0
        self.last_detection_time = time.time()

        # Rep buffer state (decoupled from state machine)
        self.current_rep_buffer = []
        self._rep_frame_index = 0
        self._is_buffering = False
        self._buffer_start_time = 0.0
        self._buffer_saw_squatting = False

    def reset(self):
        self.correct_count = 0
        self.incorrect_count = 0
        self.state = "standing"
        self.feedback = ""
        self.knee_angle = 0.0
        self.hip_angle = 0.0

        # Reset buffer state
        self.current_rep_buffer = []
        self._rep_frame_index = 0
        self._is_buffering = False
        self._buffer_start_time = 0.0
        self._buffer_saw_squatting = False

    def close(self):
        self.landmarker.close()

    def process_frame(self, frame):
        h, w, _ = frame.shape

        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        self.frame_timestamp_ms += 33
        results = self.landmarker.detect_for_video(mp_image, self.frame_timestamp_ms)

        if not results.pose_landmarks or len(results.pose_landmarks) == 0:
            elapsed = time.time() - self.last_detection_time
            if elapsed > INACTIVE_THRESH:
                self.reset()
            self.last_pose_landmarks = []
            return frame

        self.last_detection_time = time.time()
        landmarks = results.pose_landmarks[0]
        self.last_pose_landmarks = [
            {"x": float(lm.x), "y": float(lm.y), "z": float(getattr(lm, "z", 0.0))}
            for lm in landmarks
        ]

        self._draw_landmarks(frame, landmarks, w, h)

        l_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_shoulder"], w, h)
        r_shoulder = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_shoulder"], w, h)
        l_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_hip"], w, h)
        r_hip = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_hip"], w, h)
        l_knee = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_knee"], w, h)
        r_knee = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_knee"], w, h)
        l_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["left_ankle"], w, h)
        r_ankle = get_landmark_coords_from_normalized(landmarks, LANDMARKS["right_ankle"], w, h)

        offset_angle = find_offset_angle(l_shoulder, l_hip)
        if offset_angle > OFFSET_THRESH:
            self.feedback = f"Align to side view ({offset_angle:.0f}°)"
            return frame

        l_knee_angle = find_angle(l_hip, l_knee, l_ankle)
        r_knee_angle = find_angle(r_hip, r_knee, r_ankle)
        self.knee_angle = (l_knee_angle + r_knee_angle) / 2

        l_hip_angle = find_angle(l_shoulder, l_hip, l_knee)
        r_hip_angle = find_angle(r_shoulder, r_hip, r_knee)
        self.hip_angle = (l_hip_angle + r_hip_angle) / 2

        t = self.thresh

        # --- Buffer logic (decoupled from state machine) ---
        # Start buffering when knee angle drops below threshold (descent starting)
        if not self._is_buffering and self.knee_angle < BUFFER_KNEE_START:
            self._is_buffering = True
            self._buffer_start_time = time.time()
            self._buffer_saw_squatting = False
            self._rep_frame_index = 0
            self.current_rep_buffer = []

        # Continue buffering while in the rep window
        if self._is_buffering:
            self._append_to_rep_buffer()

            # Check for buffer timeout (user didn't actually squat)
            elapsed = time.time() - self._buffer_start_time
            if elapsed > BUFFER_TIMEOUT_SECONDS and not self._buffer_saw_squatting:
                # Discard buffer - user bent knees but didn't complete a squat
                self._is_buffering = False
                self.current_rep_buffer = []
                self._rep_frame_index = 0

        # --- State machine (unchanged thresholds, unchanged counting logic) ---
        if self.state == "standing" and self.knee_angle < t["knee_angle_low"]:
            self.state = "squatting"
            self._buffer_saw_squatting = True  # Mark that we've entered squatting
            form_ok = t["hip_angle_low"] <= self.hip_angle <= t["hip_angle_high"]
            self.feedback = "Good depth!" if form_ok else f"Watch torso ({self.hip_angle:.0f}°)"

        elif self.state == "squatting" and self.knee_angle > t["knee_angle_high"]:
            # Rep complete - squatting → standing
            self.state = "standing"

            # Analyze the rep using smoothed values from deepest position
            rep_analysis = self._analyze_rep()

            # Form check: depth + torso lean at deepest position
            is_correct = t["hip_angle_low"] <= rep_analysis["hip_angle"] <= t["hip_angle_high"]

            if is_correct:
                self.correct_count += 1
                self.feedback = "Good rep!"
            else:
                self.incorrect_count += 1
                self.feedback = f"Check torso lean ({rep_analysis['hip_angle']:.0f}°)"

            if self.on_rep_complete:
                # Pass a copy of the buffer since it may continue to be modified
                self.on_rep_complete({
                    "rep_number": self.correct_count + self.incorrect_count,
                    "is_correct": is_correct,
                    "knee_angle": rep_analysis["knee_angle"],
                    "hip_angle": rep_analysis["hip_angle"],
                    "mode": self.mode,
                    "correct_count": self.correct_count,
                    "incorrect_count": self.incorrect_count,
                    "rep_trajectory": list(self.current_rep_buffer),
                    "deepest_frame_index": rep_analysis["deepest_frame_index"],
                    "tempo": rep_analysis["tempo"],
                })

            # Buffer continues until knee angle returns above BUFFER_KNEE_END
            # (handled below)

        # --- Stop buffering when fully standing again ---
        # Only stop if we've passed through squatting and are now back up
        if self._is_buffering and self._buffer_saw_squatting and self.knee_angle > BUFFER_KNEE_END:
            # Rep is fully complete, stop buffering
            self._is_buffering = False
            self.current_rep_buffer = []
            self._rep_frame_index = 0
            self._buffer_saw_squatting = False

        return frame

    def _append_to_rep_buffer(self):
        """Append current frame data to the rep buffer."""
        self.current_rep_buffer.append({
            "frame_index": self._rep_frame_index,
            "timestamp_ms": self.frame_timestamp_ms,
            "landmarks": list(self.last_pose_landmarks),  # copy the list
            "knee_angle": self.knee_angle,
            "hip_angle": self.hip_angle,
        })
        self._rep_frame_index += 1

    def _analyze_rep(self):
        """
        Analyze a completed rep using smoothed values from a 5-frame window
        around the deepest position. Returns dict with angles and tempo.
        """
        buf = self.current_rep_buffer

        if not buf:
            # Defensive: empty buffer
            return {
                "knee_angle": 0.0,
                "hip_angle": 0.0,
                "deepest_frame_index": None,
                "tempo": {"descent_seconds": None, "ascent_seconds": None},
            }

        # Find deepest frame index (minimum knee_angle)
        i_min = min(range(len(buf)), key=lambda i: buf[i]["knee_angle"])

        # Get 5-frame window centered on i_min, clamped to buffer edges
        window_size = 5
        half = window_size // 2
        start = max(0, i_min - half)
        end = min(len(buf), i_min + half + 1)
        window_frames = buf[start:end]

        # Compute median knee_angle and hip_angle over window
        knee_angles = [f["knee_angle"] for f in window_frames]
        hip_angles = [f["hip_angle"] for f in window_frames]
        median_knee = statistics.median(knee_angles)
        median_hip = statistics.median(hip_angles)

        # Compute tempo
        tempo = self._compute_tempo(i_min, len(buf))

        return {
            "knee_angle": median_knee,
            "hip_angle": median_hip,
            "deepest_frame_index": i_min,
            "tempo": tempo,
        }

    def _compute_tempo(self, deepest_index, buffer_length):
        """
        Compute descent and ascent timing.
        descent_frames = frames from start to deepest
        ascent_frames = frames from deepest to end
        Convert to seconds assuming ~33ms per frame.

        Returns None for descent/ascent if too few frames to be reliable.
        """
        descent_frames = deepest_index
        ascent_frames = buffer_length - deepest_index - 1

        # Convert to seconds (33ms per frame = ~30fps)
        ms_per_frame = 33

        # Sanity check: if fewer than 3 frames, timing is unreliable
        min_frames_for_timing = 3

        if descent_frames >= min_frames_for_timing:
            descent_seconds = round((descent_frames * ms_per_frame) / 1000.0, 2)
        else:
            descent_seconds = None  # Insufficient data

        if ascent_frames >= min_frames_for_timing:
            ascent_seconds = round((ascent_frames * ms_per_frame) / 1000.0, 2)
        else:
            ascent_seconds = None  # Insufficient data

        return {
            "descent_seconds": descent_seconds,
            "ascent_seconds": ascent_seconds,
        }

    def _draw_landmarks(self, frame, landmarks, w, h):
        for connection in POSE_CONNECTIONS:
            start = landmarks[connection.start]
            end = landmarks[connection.end]
            x1, y1 = int(start.x * w), int(start.y * h)
            x2, y2 = int(end.x * w), int(end.y * h)
            cv2.line(frame, (x1, y1), (x2, y2), (245, 66, 230), 2)

        for lm in landmarks:
            cx, cy = int(lm.x * w), int(lm.y * h)
            cv2.circle(frame, (cx, cy), 4, (245, 117, 66), -1)
